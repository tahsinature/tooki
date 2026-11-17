use crate::*;
use std::{
    cell::RefCell,
    collections::{HashSet, VecDeque},
    ptr::null_mut,
    sync::mpsc::SyncSender,
    time::Duration,
};
use windows_sys::Win32::{
    Foundation::*,
    System::{LibraryLoader::GetModuleHandleW, Threading::*},
    UI::{Input::KeyboardAndMouse::*, WindowsAndMessaging::*},
};
#[derive(Default)]
struct HookState {
    block: bool,
    down: HashSet<u32>,
    swallowed: HashSet<u32>,
    events: VecDeque<(Combo, u32, bool)>,
}
thread_local! { static STATE:RefCell<HookState>=RefCell::new(HookState::default()); }
pub fn capabilities() -> Capabilities {
    Capabilities {platform:"Windows".into(),can_observe:true,can_block:true,explanation:"Observes keyboard shortcuts and can block presses received by Tooki. Windows does not expose every global hotkey owner. Elevated apps, secure desktops and earlier hooks may be outside detection; no result means no observation, not that a shortcut is free.".into()}
}
fn key(code: u32) -> Option<String> {
    match code {
        0x41..=0x5a => Some((code as u8 as char).to_ascii_lowercase().to_string()),
        0x30..=0x39 => Some((code as u8 as char).to_string()),
        0x70..=0x87 => Some(format!("f{}", code - 0x6f)),
        0x08 => Some("backspace".into()),
        0x09 => Some("tab".into()),
        0x0d => Some("enter".into()),
        0x1b => Some("escape".into()),
        0x20 => Some("space".into()),
        0x21 => Some("pageup".into()),
        0x22 => Some("pagedown".into()),
        0x23 => Some("end".into()),
        0x24 => Some("home".into()),
        0x25 => Some("left".into()),
        0x26 => Some("up".into()),
        0x27 => Some("right".into()),
        0x28 => Some("down".into()),
        0x2d => Some("insert".into()),
        0x2e => Some("delete".into()),
        0xba => Some(";".into()),
        0xbb => Some("=".into()),
        0xbc => Some(",".into()),
        0xbd => Some("-".into()),
        0xbe => Some(".".into()),
        0xbf => Some("/".into()),
        0xc0 => Some("`".into()),
        0xdb => Some("[".into()),
        0xdc => Some("\\".into()),
        0xdd => Some("]".into()),
        0xde => Some("'".into()),
        _ => None,
    }
}
unsafe extern "system" fn hook(code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    if code < 0 {
        return CallNextHookEx(null_mut(), code, wparam, lparam);
    }
    let event = &*(lparam as *const KBDLLHOOKSTRUCT);
    // Ignore synthetic events, including paste automation, rather than diagnosing our own output.
    if event.flags & LLKHF_INJECTED != 0 {
        return CallNextHookEx(null_mut(), code, wparam, lparam);
    }
    let is_up = wparam as u32 == WM_KEYUP || wparam as u32 == WM_SYSKEYUP;
    if is_up {
        let blocked = STATE.with(|state| {
            let mut state = state.borrow_mut();
            state.down.remove(&event.vkCode);
            state.swallowed.remove(&event.vkCode)
        });
        return if blocked {
            1
        } else {
            CallNextHookEx(null_mut(), code, wparam, lparam)
        };
    }
    if wparam as u32 != WM_KEYDOWN && wparam as u32 != WM_SYSKEYDOWN {
        return CallNextHookEx(null_mut(), code, wparam, lparam);
    }
    let (repeat, blocked) = STATE.with(|s| {
        let mut s = s.borrow_mut();
        (
            !s.down.insert(event.vkCode),
            s.swallowed.contains(&event.vkCode),
        )
    });
    if repeat {
        return if blocked {
            1
        } else {
            CallNextHookEx(null_mut(), code, wparam, lparam)
        };
    }
    let pressed = |key| GetAsyncKeyState(key as i32) < 0;
    let mods = if pressed(VK_CONTROL) { CONTROL } else { 0 }
        | if pressed(VK_MENU) { ALT } else { 0 }
        | if pressed(VK_SHIFT) { SHIFT } else { 0 }
        | if pressed(VK_LWIN) || pressed(VK_RWIN) {
            SUPER
        } else {
            0
        };
    let combo = key(event.vkCode).and_then(|k| Combo::new(&k, mods));
    let Some(combo) = combo else {
        return CallNextHookEx(null_mut(), code, wparam, lparam);
    };
    let mut pid = 0;
    GetWindowThreadProcessId(GetForegroundWindow(), &mut pid);
    let block = STATE.with(|s| s.borrow().block);
    let downstream = if block {
        1
    } else {
        CallNextHookEx(null_mut(), code, wparam, lparam)
    };
    STATE.with(|s| {
        let mut s = s.borrow_mut();
        if block {
            s.swallowed.insert(event.vkCode);
        }
        if s.events.len() < 256 {
            s.events.push_back((combo, pid, downstream != 0));
        }
    });
    downstream
}
fn app_name(pid: u32) -> Option<String> {
    unsafe {
        let process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
        if process.is_null() {
            return None;
        }
        let mut path = [0u16; 1024];
        let mut length = path.len() as u32;
        let ok = QueryFullProcessImageNameW(process, 0, path.as_mut_ptr(), &mut length);
        CloseHandle(process);
        if ok == 0 {
            return None;
        }
        Some(
            String::from_utf16_lossy(&path[..length as usize])
                .rsplit('\\')
                .next()?
                .to_string(),
        )
    }
}
pub fn run(
    mode: Mode,
    running: &dyn Fn() -> bool,
    report: &mut dyn FnMut(Check),
    ready: SyncSender<Result<(), String>>,
) -> Result<(), String> {
    STATE.with(|s| {
        *s.borrow_mut() = HookState {
            block: mode == Mode::Block,
            ..Default::default()
        }
    });
    unsafe {
        let handle = SetWindowsHookExW(
            WH_KEYBOARD_LL,
            Some(hook),
            GetModuleHandleW(std::ptr::null()),
            0,
        );
        if handle.is_null() {
            let error = format!(
                "Windows could not install keyboard monitoring ({}).",
                GetLastError()
            );
            let _ = ready.send(Err(error.clone()));
            return Err(error);
        }
        let _ = ready.send(Ok(()));
        while running() {
            let mut message: MSG = std::mem::zeroed();
            while PeekMessageW(&mut message, null_mut(), 0, 0, PM_REMOVE) != 0 {
                TranslateMessage(&message);
                DispatchMessageW(&message);
            }
            let events = STATE.with(|s| std::mem::take(&mut s.borrow_mut().events));
            for (combo, pid, blocked) in events {
                let (outcome, detail) = if mode == Mode::Block {
                    (
                        "lookup",
                        "Tooki blocked this press. Only known assignments are listed.",
                    )
                } else if blocked {
                    ("intercepted","A later keyboard hook blocked this press. Windows does not reveal its owner.")
                } else {
                    ("observed","Observed a shortcut press. The hook chain did not report blocking; app delivery and the shortcut owner cannot be confirmed.")
                };
                if running() {
                    report(Check {
                        combo,
                        outcome: outcome.into(),
                        detail: detail.into(),
                        app: app_name(pid),
                        matches: vec![],
                    });
                }
            }
            std::thread::sleep(Duration::from_millis(10));
        }
        UnhookWindowsHookEx(handle);
    }
    STATE.with(|s| *s.borrow_mut() = HookState::default());
    Ok(())
}
