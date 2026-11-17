#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <sys/sysctl.h>
#include <sys/mount.h>
#include <sys/resource.h>
#include <libproc.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/route.h>
#include <arpa/inet.h>

static id Number(const char *key) {
    uint64_t value = 0; size_t size = sizeof(value);
    return sysctlbyname(key, &value, &size, NULL, 0) == 0 ? @(value) : NSNull.null;
}
static NSString *Text(const char *key) {
    char value[256] = {0}; size_t size = sizeof(value);
    return sysctlbyname(key, value, &size, NULL, 0) == 0 ? @(value) : @"Unavailable";
}
static NSDictionary *Registry(NSString *name) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(name.UTF8String));
    if (!service) return @{};
    CFMutableDictionaryRef properties = NULL;
    IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0);
    IOObjectRelease(service);
    return properties ? CFBridgingRelease(properties) : @{};
}
static NSDictionary *Battery(void) {
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (!info) return @{};
    NSArray *sources = CFBridgingRelease(IOPSCopyPowerSourcesList(info));
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (id source in sources) {
        NSDictionary *p = (__bridge NSDictionary *)IOPSGetPowerSourceDescription(info, (__bridge CFTypeRef)source);
        if (![p[@kIOPSTypeKey] isEqual:@kIOPSInternalBatteryType]) continue;
        double maximum = [p[@kIOPSMaxCapacityKey] doubleValue];
        if (maximum > 0) result[@"percent"] = @([p[@kIOPSCurrentCapacityKey] doubleValue] * 100 / maximum);
        result[@"charging"] = p[@kIOPSIsChargingKey] ?: @NO;
        result[@"source"] = p[@kIOPSPowerSourceStateKey] ?: @"Unavailable";
        double remaining = IOPSGetTimeRemainingEstimate();
        if (remaining > 0) result[@"remainingSeconds"] = @(remaining);
        NSDictionary *hardware = Registry(@"AppleSmartBattery");
        result[@"cycles"] = hardware[@"CycleCount"] ?: NSNull.null;
        double design = [hardware[@"DesignCapacity"] doubleValue];
        double capacity = [hardware[@"AppleRawMaxCapacity"] doubleValue];
        if (design > 0 && capacity > 0) result[@"health"] = @(MIN(100, capacity * 100 / design));
        break;
    }
    CFRelease(info);
    return result;
}
static NSArray *Interfaces(void) {
    struct ifaddrs *addresses = NULL;
    if (getifaddrs(&addresses) != 0) return @[];
    NSMutableDictionary *rows = [NSMutableDictionary dictionary];
    for (struct ifaddrs *a = addresses; a; a = a->ifa_next) {
        if (!a->ifa_addr || !(a->ifa_flags & IFF_UP) || (a->ifa_flags & IFF_LOOPBACK)) continue;
        NSString *name = @(a->ifa_name);
        NSMutableDictionary *row = rows[name];
        if (!row) rows[name] = row = [@{@"name":name} mutableCopy];
        if (a->ifa_addr->sa_family == AF_INET) {
            char address[INET_ADDRSTRLEN];
            if (inet_ntop(AF_INET, &((struct sockaddr_in *)a->ifa_addr)->sin_addr, address, sizeof(address))) row[@"address"] = @(address);
        } else if (a->ifa_addr->sa_family == AF_INET6 && !row[@"address"]) {
            char address[INET6_ADDRSTRLEN];
            if (inet_ntop(AF_INET6, &((struct sockaddr_in6 *)a->ifa_addr)->sin6_addr, address, sizeof(address))) row[@"address"] = @(address);
        }
    }
    freeifaddrs(addresses);
    // getifaddrs exposes 32-bit byte counters on macOS. Use the routing
    // snapshot's 64-bit counters so fast transfers do not wrap every 4 GB.
    int mib[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0};
    size_t size = 0;
    if (sysctl(mib, 6, NULL, &size, NULL, 0) == 0 && size > 0) {
        char *buffer = malloc(size);
        if (buffer && sysctl(mib, 6, buffer, &size, NULL, 0) == 0) {
            char *end = buffer + size;
            for (char *cursor = buffer; cursor + sizeof(struct if_msghdr) <= end;) {
                struct if_msghdr *header = (struct if_msghdr *)cursor;
                if (!header->ifm_msglen || cursor + header->ifm_msglen > end) break;
                if (header->ifm_type == RTM_IFINFO2 && header->ifm_msglen >= sizeof(struct if_msghdr2)) {
                    struct if_msghdr2 *message = (struct if_msghdr2 *)cursor;
                    char name[IF_NAMESIZE];
                    if (if_indextoname(message->ifm_index, name) && rows[@(name)]) {
                        rows[@(name)][@"received"] = @(message->ifm_data.ifi_ibytes);
                        rows[@(name)][@"sent"] = @(message->ifm_data.ifi_obytes);
                    }
                }
                cursor += header->ifm_msglen;
            }
        }
        free(buffer);
    }
    NSDictionary *route = CFBridgingRelease(SCDynamicStoreCopyValue(NULL, CFSTR("State:/Network/Global/IPv4")));
    if (!route[@"PrimaryInterface"]) route = CFBridgingRelease(SCDynamicStoreCopyValue(NULL, CFSTR("State:/Network/Global/IPv6")));
    NSString *primary = route[@"PrimaryInterface"];
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *name in [[rows allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        NSMutableDictionary *row = rows[name];
        if (!row[@"received"] || !row[@"address"]) continue;
        row[@"primary"] = @([name isEqual:primary]);
        [result addObject:row];
    }
    return result;
}
static NSArray *Processes(void) {
    mach_timebase_info_data_t timebase;
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || !timebase.denom) return @[];
    int size = proc_listallpids(NULL, 0);
    if (size <= 0) return @[];
    size += 256;
    pid_t *pids = calloc(size, sizeof(pid_t));
    if (!pids) return @[];
    int count = proc_listallpids(pids, size * sizeof(pid_t));
    NSMutableArray *result = [NSMutableArray array];
    for (int i = 0; i < MIN(count, size); i++) {
        struct rusage_info_v2 usage = {0};
        if (pids[i] <= 0 || proc_pid_rusage(pids[i], RUSAGE_INFO_V2, (rusage_info_t *)&usage)) continue;
        char name[PROC_PIDPATHINFO_MAXSIZE] = {0};
        proc_name(pids[i], name, sizeof(name));
        // proc_pid_rusage returns Mach ticks, which are not nanoseconds on Apple Silicon.
        uint64_t cpuNanoseconds = (uint64_t)(((__uint128_t)usage.ri_user_time + usage.ri_system_time) * timebase.numer / timebase.denom);
        [result addObject:@{@"pid":@(pids[i]), @"name":name[0] ? @(name) : @"Process",
            @"start":@(usage.ri_proc_start_abstime), @"cpuTime":@(cpuNanoseconds),
            @"memory":@(usage.ri_phys_footprint)}];
    }
    free(pids);
    return result;
}
static NSDictionary *Storage(void) {
    // The writable Data volume shares APFS container space with the system volume.
    NSURL *url = [NSURL fileURLWithPath:@"/System/Volumes/Data"];
    struct statfs fs;
    if (statfs(url.path.fileSystemRepresentation, &fs)) return @{};
    NSString *name; [url getResourceValue:&name forKey:NSURLVolumeNameKey error:nil];
    NSMutableDictionary *result = [@{@"name":name ?: @"Startup disk", @"format":@(fs.f_fstypename),
        @"total":@((uint64_t)fs.f_blocks * fs.f_bsize), @"available":@((uint64_t)fs.f_bavail * fs.f_bsize)} mutableCopy];
    io_iterator_t iterator = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS) {
        uint64_t read = 0, written = 0; bool found = false; io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            NSDictionary *stats = CFBridgingRelease(IORegistryEntryCreateCFProperty(service, CFSTR("Statistics"), kCFAllocatorDefault, 0));
            if (stats[@"Bytes (Read)"] && stats[@"Bytes (Write)"]) {
                read += [stats[@"Bytes (Read)"] unsignedLongLongValue]; written += [stats[@"Bytes (Write)"] unsignedLongLongValue]; found = true;
            }
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
        if (found) { result[@"readBytes"] = @(read); result[@"writtenBytes"] = @(written); }
    }
    return result;
}
char *tooki_system_monitor_snapshot(void) {
    @autoreleasepool {
        NSProcessInfo *info = NSProcessInfo.processInfo;
        NSMutableDictionary *result = [@{@"uptime":@(info.systemUptime), @"hostname":NSHost.currentHost.localizedName ?: @"This Mac",
            @"os":info.operatingSystemVersionString, @"model":Text("hw.model"), @"chip":Text("machdep.cpu.brand_string"),
            @"physicalCores":Number("hw.physicalcpu"), @"logicalCores":Number("hw.logicalcpu"),
            @"performanceCores":Number("hw.perflevel0.physicalcpu"), @"efficiencyCores":Number("hw.perflevel1.physicalcpu"),
            @"memoryTotal":@(info.physicalMemory), @"battery":Battery(), @"interfaces":Interfaces(),
            @"processes":Processes(), @"storage":Storage()} mutableCopy];
        host_t host = mach_host_self();
        natural_t count = 0; processor_info_array_t ticks = NULL; mach_msg_type_number_t length = 0;
        NSMutableArray *cores = [NSMutableArray array];
        if (host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &count, &ticks, &length) == KERN_SUCCESS) {
            for (natural_t i = 0; i < count; i++) {
                NSMutableArray *core = [NSMutableArray array];
                for (int j = 0; j < CPU_STATE_MAX; j++) [core addObject:@((uint32_t)ticks[i * CPU_STATE_MAX + j])];
                [cores addObject:core];
            }
            vm_deallocate(mach_task_self(), (vm_address_t)ticks, length * sizeof(integer_t));
        }
        result[@"cpuTicks"] = cores;
        vm_statistics64_data_t vm; mach_msg_type_number_t vmCount = HOST_VM_INFO64_COUNT;
        vm_size_t pageSize = 0; host_page_size(host, &pageSize);
        if (host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm, &vmCount) == KERN_SUCCESS) {
            uint64_t usedPages = (uint64_t)vm.active_count + vm.inactive_count + vm.wire_count + vm.compressor_page_count;
            // File-backed pages are reclaimable cache, not application memory.
            usedPages -= MIN(usedPages, (uint64_t)vm.external_page_count);
            result[@"memory"] = @{@"used":@(MIN(info.physicalMemory, usedPages * pageSize)), @"wired":@((uint64_t)vm.wire_count * pageSize),
                @"compressed":@((uint64_t)vm.compressor_page_count * pageSize), @"pressure":Number("kern.memorystatus_vm_pressure_level")};
        }
        mach_port_deallocate(mach_task_self(), host);
        struct xsw_usage swap = {0}; size_t swapSize = sizeof(swap);
        if (!sysctlbyname("vm.swapusage", &swap, &swapSize, NULL, 0)) result[@"swapUsed"] = @(swap.xsu_used);
        double load[3]; if (getloadavg(load, 3) == 3) result[@"loadAverage"] = @[@(load[0]), @(load[1]), @(load[2])];
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        return data ? strdup([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String) : NULL;
    }
}
void tooki_system_monitor_free(char *value) { free(value); }
