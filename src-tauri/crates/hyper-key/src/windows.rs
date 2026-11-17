use std::{cell::RefCell, ptr::null_mut, sync::mpsc, thread::JoinHandle, time::Instant};
use windows_sys::Win32::{
    Foundation::*,
    System::{
        LibraryLoader::GetModuleHandleW,
        Threading::{CreateMutexW, GetCurrentThreadId},
    },
    UI::{Input::KeyboardAndMouse::*, WindowsAndMessaging::*},
};
const MARKER: usize = 0x544f4f4b;
const MODIFIERS: [u16; 4] = [VK_LCONTROL, VK_LMENU, VK_LSHIFT, VK_LWIN];
#[derive(Default)]
struct State {
    pressed: Option<Instant>,
    used: bool,
    injected: Vec<u16>,
}
thread_local! { static STATE:RefCell<State> = RefCell::new(State::default()); }
unsafe fn send(key: u16, up: bool) -> bool {
    let input = INPUT {
        r#type: INPUT_KEYBOARD,
        Anonymous: INPUT_0 {
            ki: KEYBDINPUT {
                wVk: key,
                wScan: 0,
                dwFlags: if up { KEYEVENTF_KEYUP } else { 0 },
                time: 0,
                dwExtraInfo: MARKER,
            },
        },
    };
    SendInput(1, &input, std::mem::size_of::<INPUT>() as i32) == 1
}
unsafe fn release() {
    // Only release modifiers synthesized by this session.
    let keys = STATE.with(|s| std::mem::take(&mut s.borrow_mut().injected));
    for key in keys.into_iter().rev() {
        send(key, true);
    }
}
unsafe extern "system" fn hook(code: i32, w: WPARAM, l: LPARAM) -> LRESULT {
    if code < 0 {
        return CallNextHookEx(null_mut(), code, w, l);
    }
    let event = &*(l as *const KBDLLHOOKSTRUCT);
    if event.flags & LLKHF_INJECTED != 0 {
        return CallNextHookEx(null_mut(), code, w, l);
    }
    let up = matches!(w as u32, WM_KEYUP | WM_SYSKEYUP);
    if event.vkCode == VK_CAPITAL as u32 {
        if up {
            let tap = STATE.with(|s| {
                let mut s = s.borrow_mut();
                let tap = s
                    .pressed
                    .take()
                    .is_some_and(|t| t.elapsed().as_millis() < 300)
                    && !s.used;
                s.used = false;
                tap
            });
            release();
            if tap {
                send(VK_CAPITAL, false);
                send(VK_CAPITAL, true);
            }
        } else {
            STATE.with(|s| {
                let mut s = s.borrow_mut();
                if s.pressed.is_none() {
                    s.pressed = Some(Instant::now());
                    s.used = false;
                }
            });
        }
        return 1;
    }
    let activate = STATE.with(|s| {
        let mut s = s.borrow_mut();
        let active = s.pressed.is_some() && !s.used && !up;
        if active {
            s.used = true;
        }
        active
    });
    if activate {
        for key in MODIFIERS {
            if GetAsyncKeyState(key as i32) >= 0 && send(key, false) {
                STATE.with(|s| s.borrow_mut().injected.push(key));
            }
        }
    }
    CallNextHookEx(null_mut(), code, w, l)
}
pub struct Session {
    id: u32,
    thread: Option<JoinHandle<()>>,
}
impl Session {
    pub fn start() -> Result<Self, String> {
        let (tx, rx) = mpsc::sync_channel(1);
        let thread = std::thread::spawn(move || unsafe {
            let name: Vec<u16> = "Local\\TookiPreviewHyperKey"
                .encode_utf16()
                .chain(Some(0))
                .collect();
            let owner = CreateMutexW(std::ptr::null(), 0, name.as_ptr());
            if owner.is_null() || GetLastError() == ERROR_ALREADY_EXISTS {
                if !owner.is_null() {
                    CloseHandle(owner);
                }
                let _=tx.send(Err("Hyper Key is already active in another Tooki instance, or its ownership lock could not be opened.".to_string()));
                return;
            }
            let mut message: MSG = std::mem::zeroed();
            PeekMessageW(&mut message, null_mut(), 0, 0, PM_NOREMOVE);
            let hook = SetWindowsHookExW(
                WH_KEYBOARD_LL,
                Some(hook),
                GetModuleHandleW(std::ptr::null()),
                0,
            );
            if hook.is_null() {
                CloseHandle(owner);
                let _ = tx.send(Err("Could not start the Windows keyboard hook.".to_string()));
                return;
            }
            let _ = tx.send(Ok(GetCurrentThreadId()));
            while GetMessageW(&mut message, null_mut(), 0, 0) > 0 {
                TranslateMessage(&message);
                DispatchMessageW(&message);
            }
            release();
            UnhookWindowsHookEx(hook);
            CloseHandle(owner);
        });
        match rx.recv().map_err(|e| e.to_string())? {
            Ok(id) => Ok(Self {
                id,
                thread: Some(thread),
            }),
            Err(error) => {
                let _ = thread.join();
                Err(error)
            }
        }
    }
}
impl Drop for Session {
    fn drop(&mut self) {
        unsafe {
            PostThreadMessageW(self.id, WM_QUIT, 0, 0);
        }
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}
