use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    Compact,
    Expanded,
}
#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq)]
pub struct Size {
    pub width: f64,
    pub height: f64,
}
impl Default for Size {
    fn default() -> Self {
        Self {
            width: 760.0,
            height: 520.0,
        }
    }
}
impl Size {
    pub fn valid(self) -> bool {
        self.width.is_finite()
            && self.height.is_finite()
            && self.width >= 680.0
            && self.height >= 84.0
    }
    pub fn fit(self, available: Self) -> Self {
        Self {
            width: self.width.min(available.width).max(680.0),
            height: self.height.min(available.height).max(84.0),
        }
    }
    fn matches(self, other: Self) -> bool {
        (self.width - other.width).abs() < 1.0 && (self.height - other.height).abs() < 1.0
    }
}
#[derive(Default)]
pub struct Sizing {
    pub preferred: Size,
    pub applied: Option<(Mode, Size)>,
}
impl Sizing {
    // Observe the current frame before hiding or applying another layout. Native
    // resize events also fire for our own layouts, so they cannot identify user edits.
    pub fn capture(&mut self, current: Size) -> bool {
        let Some((mode, applied)) = self.applied else {
            return false;
        };
        if !current.valid() || current.matches(applied) {
            return false;
        }
        let preferred = Size {
            width: if (current.width - applied.width).abs() >= 1.0 {
                current.width
            } else {
                self.preferred.width
            },
            height: if mode == Mode::Expanded && (current.height - applied.height).abs() >= 1.0 {
                current.height
            } else {
                self.preferred.height
            },
        };
        self.applied = Some((mode, current));
        if preferred.matches(self.preferred) {
            return false;
        }
        self.preferred = preferred;
        true
    }
    pub fn target(&self, mode: Mode, header_height: f64, available: Size) -> Size {
        Size {
            width: self.preferred.width,
            height: match mode {
                Mode::Compact => header_height + 40.0,
                Mode::Expanded => self.preferred.height,
            },
        }
        .fit(available)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    const DISPLAY: Size = Size {
        width: 1440.0,
        height: 900.0,
    };
    #[test]
    fn manual_size_survives_compact_and_reopen() {
        let mut sizing = Sizing::default();
        sizing.applied = Some((Mode::Expanded, Size::default()));
        assert!(sizing.capture(Size {
            width: 1024.0,
            height: 650.0
        }));
        let compact = sizing.target(Mode::Compact, 80.0, DISPLAY);
        assert_eq!(
            compact,
            Size {
                width: 1024.0,
                height: 120.0
            }
        );
        sizing.applied = Some((Mode::Compact, compact));
        assert!(!sizing.capture(compact));
        assert_eq!(
            sizing.target(Mode::Expanded, 54.0, DISPLAY),
            Size {
                width: 1024.0,
                height: 650.0
            }
        );
    }
    #[test]
    fn compact_resizing_only_changes_saved_width() {
        let mut sizing = Sizing::default();
        sizing.applied = Some((
            Mode::Compact,
            Size {
                width: 760.0,
                height: 94.0,
            },
        ));
        assert!(sizing.capture(Size {
            width: 900.0,
            height: 110.0
        }));
        assert_eq!(
            sizing.preferred,
            Size {
                width: 900.0,
                height: 520.0
            }
        );
    }
    #[test]
    fn smaller_display_does_not_replace_preferred_dimensions() {
        let preferred = Size {
            width: 1300.0,
            height: 800.0,
        };
        let mut sizing = Sizing {
            preferred,
            applied: None,
        };
        let fitted = sizing.target(
            Mode::Expanded,
            54.0,
            Size {
                width: 1000.0,
                height: 700.0,
            },
        );
        assert_eq!(
            fitted,
            Size {
                width: 1000.0,
                height: 700.0
            }
        );
        sizing.applied = Some((Mode::Expanded, fitted));
        assert!(!sizing.capture(fitted));
        assert_eq!(sizing.target(Mode::Expanded, 54.0, DISPLAY), preferred);
        assert!(sizing.capture(Size {
            width: fitted.width,
            height: 600.0
        }));
        assert_eq!(
            sizing.preferred,
            Size {
                width: 1300.0,
                height: 600.0
            }
        );
    }
    #[test]
    fn startup_and_invalid_frames_cannot_overwrite_saved_size() {
        let mut sizing = Sizing::default();
        assert!(!sizing.capture(Size {
            width: 760.0,
            height: 94.0
        }));
        sizing.applied = Some((Mode::Expanded, Size::default()));
        assert!(!sizing.capture(Size {
            width: f64::NAN,
            height: 500.0
        }));
        assert!(!sizing.capture(Size {
            width: 0.0,
            height: 0.0
        }));
    }
}
