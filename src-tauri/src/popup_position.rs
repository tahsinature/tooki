pub(crate) fn position(
    x: f64,
    top: f64,
    bottom: f64,
    width: f64,
    height: f64,
    left: f64,
    screen_top: f64,
    screen_width: f64,
    screen_height: f64,
    gap: f64,
) -> (f64, f64) {
    let y = if top - height - gap >= screen_top {
        top - height - gap
    } else {
        bottom + gap
    };
    (
        x.clamp(left, (left + screen_width - width).max(left)),
        y.clamp(
            screen_top,
            (screen_top + screen_height - height).max(screen_top),
        ),
    )
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn anchors_above_or_below_without_resizing_the_parent() {
        assert_eq!(
            position(110., 400., 430., 350., 220., 0., 0., 1000., 800., 6.),
            (110., 174.)
        );
        assert_eq!(
            position(900., 20., 50., 350., 220., 0., 0., 1000., 800., 6.),
            (650., 56.)
        );
        assert_eq!(
            position(-800., 400., 430., 350., 220., -1000., 0., 1000., 800., 6.),
            (-800., 174.)
        );
    }
}

/// Prefer below the trigger, flip above at the screen edge, then clamp.
pub(crate) fn below(
    x: f64,
    top: f64,
    bottom: f64,
    width: f64,
    height: f64,
    left: f64,
    screen_top: f64,
    screen_width: f64,
    screen_height: f64,
    gap: f64,
) -> (f64, f64) {
    let y = if bottom + gap + height <= screen_top + screen_height {
        bottom + gap
    } else {
        top - gap - height
    };
    (
        x.clamp(left, (left + screen_width - width).max(left)),
        y.clamp(
            screen_top,
            (screen_top + screen_height - height).max(screen_top),
        ),
    )
}
#[cfg(test)]
mod filter_tests {
    use super::*;
    #[test]
    fn filter_prefers_below_and_flips_at_the_work_area_edge() {
        assert_eq!(
            below(300., 100., 130., 202., 180., 0., 0., 1000., 800., 4.),
            (300., 134.)
        );
        assert_eq!(
            below(900., 700., 730., 202., 180., 0., 0., 1000., 800., 4.),
            (798., 516.)
        );
        assert_eq!(
            below(-1050., 100., 130., 202., 180., -1000., 0., 1000., 800., 4.),
            (-1000., 134.)
        );
    }
}
