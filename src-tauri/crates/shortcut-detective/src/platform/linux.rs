use crate::*;
use std::{collections::VecDeque, sync::mpsc::SyncSender};
use x11_dl::{xlib, xrecord};
fn wayland() -> bool {
    std::env::var_os("WAYLAND_DISPLAY").is_some()
        || std::env::var("XDG_SESSION_TYPE").is_ok_and(|v| v == "wayland")
}
pub fn capabilities() -> Capabilities {
    let wayland = wayland();
    Capabilities {platform:if wayland {"Linux · Wayland"}else{"Linux · X11"}.into(),can_observe:!wayland,can_block:false,
        explanation:if wayland {"Wayland does not provide unrestricted global keyboard observation. Use the focused lookup field for Tooki and supported desktop assignments; compositor-reserved shortcuts may not reach it. Global listening is unavailable, including through XWayland."} else {"Uses the X11 RECORD extension to observe shortcuts. It cannot identify every grab owner or safely suppress global keys. Lookup mode uses a focused field. Known assignments include Tooki and active GNOME/KDE configuration. Requires an X11 session with libX11, libXtst and RECORD enabled."}.into()}
}
struct Capture<'a> {
    record: &'a xrecord::Xf86vmode,
    events: VecDeque<(u8, u16)>,
}
unsafe extern "C" fn record_event(
    closure: *mut std::ffi::c_char,
    data: *mut xrecord::XRecordInterceptData,
) {
    let state = &mut *(closure as *mut Capture<'_>);
    if !data.is_null() {
        let packet = &*data;
        if packet.category == xrecord::XRecordFromServer
            && packet.client_swapped == 0
            && !packet.data.is_null()
        {
            // RECORD length is in four-byte units. Core KeyPress events occupy 32 bytes.
            let bytes = std::slice::from_raw_parts(
                packet.data,
                (packet.data_len as usize).saturating_mul(4),
            );
            for event in bytes.chunks_exact(32) {
                if event[0] & 0x7f == xlib::KeyPress as u8 && state.events.len() < 256 {
                    state
                        .events
                        .push_back((event[1], u16::from_ne_bytes([event[28], event[29]])));
                }
            }
        }
        (state.record.XRecordFreeData)(data);
    }
}
unsafe fn key(x: &xlib::Xlib, display: *mut xlib::Display, code: u8) -> Option<String> {
    let symbol = (x.XkbKeycodeToKeysym)(display, code, 0, 0);
    match symbol {
        0x20..=0x7e => Some((symbol as u8 as char).to_ascii_lowercase().to_string()),
        0xffbe..=0xffd5 => Some(format!("f{}", symbol - 0xffbd)),
        0xff1b => Some("escape".into()),
        0xff0d => Some("enter".into()),
        0xff09 => Some("tab".into()),
        0xff08 => Some("backspace".into()),
        0xffff => Some("delete".into()),
        0xff50 => Some("home".into()),
        0xff57 => Some("end".into()),
        0xff51 => Some("left".into()),
        0xff52 => Some("up".into()),
        0xff53 => Some("right".into()),
        0xff54 => Some("down".into()),
        0xff55 => Some("pageup".into()),
        0xff56 => Some("pagedown".into()),
        _ => None,
    }
}
pub fn run(
    mode: Mode,
    running: &dyn Fn() -> bool,
    report: &mut dyn FnMut(Check),
    ready: SyncSender<Result<(), String>>,
) -> Result<(), String> {
    let result = unsafe { run_x11(mode, running, report, &ready) };
    if let Err(error) = &result {
        let _ = ready.try_send(Err(error.clone()));
    }
    result
}
unsafe fn run_x11(
    mode: Mode,
    running: &dyn Fn() -> bool,
    report: &mut dyn FnMut(Check),
    ready: &SyncSender<Result<(), String>>,
) -> Result<(), String> {
    if wayland() || mode == Mode::Block {
        return Err(capabilities().explanation);
    }
    let x = xlib::Xlib::open().map_err(|e| format!("libX11 is unavailable: {e}"))?;
    let record = xrecord::Xf86vmode::open().map_err(|e| format!("libXtst is unavailable: {e}"))?;
    let control = (x.XOpenDisplay)(std::ptr::null());
    if control.is_null() {
        return Err("Could not connect to the X11 display.".into());
    }
    let data = (x.XOpenDisplay)(std::ptr::null());
    if data.is_null() {
        (x.XCloseDisplay)(control);
        return Err("Could not open the X11 recording connection.".into());
    }
    let result = (|| {
        let (mut major, mut minor) = (0, 0);
        if (record.XRecordQueryVersion)(control, &mut major, &mut minor) == 0 {
            return Err("This X11 server does not provide the RECORD extension.".into());
        }
        let range = (record.XRecordAllocRange)();
        if range.is_null() {
            return Err("Could not allocate the X11 recording range.".into());
        }
        (*range).device_events.first = xlib::KeyPress as u8;
        (*range).device_events.last = xlib::KeyPress as u8;
        let mut range_ptr = range;
        let mut clients = xrecord::XRecordAllClients;
        let context = (record.XRecordCreateContext)(control, 0, &mut clients, 1, &mut range_ptr, 1);
        (x.XFree)(range.cast());
        if context == 0 {
            return Err("Could not create an X11 recording context.".into());
        }
        (x.XSync)(control, 0);
        let mut capture = Capture {
            record: &record,
            events: VecDeque::new(),
        };
        let enabled = (record.XRecordEnableContextAsync)(
            data,
            context,
            Some(record_event),
            (&mut capture as *mut Capture<'_>).cast(),
        );
        let outcome = if enabled == 0 {
            Err("Could not start X11 recording.".into())
        } else {
            let _ = ready.send(Ok(()));
            let mut outcome = Ok(());
            while running() {
                let mut fd = libc::pollfd {
                    fd: (x.XConnectionNumber)(data),
                    events: libc::POLLIN,
                    revents: 0,
                };
                let status = libc::poll(&mut fd, 1, 50);
                if status < 0 || fd.revents & (libc::POLLERR | libc::POLLHUP | libc::POLLNVAL) != 0
                {
                    outcome = Err("The X11 recording connection was interrupted.".into());
                    break;
                }
                if status > 0 {
                    (record.XRecordProcessReplies)(data);
                }
                for (code, state) in capture.events.drain(..) {
                    let mods = if state & 4 != 0 { CONTROL } else { 0 }
                        | if state & 8 != 0 { ALT } else { 0 }
                        | if state & 1 != 0 { SHIFT } else { 0 }
                        | if state & 64 != 0 { SUPER } else { 0 };
                    if let Some(combo) = key(&x, control, code).and_then(|k| Combo::new(&k, mods)) {
                        if running() {
                            report(Check{combo,outcome:"observed".into(),detail:"Observed by X11 RECORD. Delivery and grab ownership cannot be determined from this observation.".into(),app:None,matches:vec![]});
                        }
                    }
                }
            }
            (record.XRecordDisableContext)(control, context);
            (x.XSync)(control, 0);
            outcome
        };
        (record.XRecordFreeContext)(control, context);
        outcome
    })();
    (x.XCloseDisplay)(data);
    (x.XCloseDisplay)(control);
    result
}
