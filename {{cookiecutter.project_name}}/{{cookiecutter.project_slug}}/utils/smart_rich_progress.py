from typing import Any

from lightning.pytorch.callbacks import RichProgressBar


def _smart_format_value(val: Any, max_sig: int = 6) -> Any:
    """Format numbers smartly for progress display.

    - ints are kept as-is
    - floats use general format with up to `max_sig` significant digits (no trailing zeros)
    - other values are returned unchanged or converted to str as a fallback
    """
    try:
        if isinstance(val, float):
            # general format removes unnecessary trailing zeros and switches to scientific
            # notation when appropriate, similar to logging-like compact output
            return format(val, f".{max_sig}g")
        if isinstance(val, int):
            return str(val)
        return val
    except Exception:
        # fallback: preserve original
        return val


class SmartRichProgressBar(RichProgressBar):
    """A small subclass of Lightning's RichProgressBar that formats numeric
    metric values more compactly instead of always showing 3 decimal places.

    It overrides `get_progress_bar_dict` and applies `_smart_format_value` to
    all displayed values. This keeps behavior compatible while improving
    readability for floats like 1.0 -> "1", 0.123456 -> "0.123456",
    and very small/large numbers in scientific notation when appropriate.
    """

    def __init__(self, *args, max_significant_digits: int = 6, **kwargs):
        super().__init__(*args, **kwargs)
        self._max_sig = max_significant_digits

    def get_metrics(self, trainer, pl_module):
        """Return progress bar metrics with smart numeric formatting.

        This overrides the Lightning `ProgressBar.get_metrics` hook which is used by
        modern versions of Lightning to collect items shown in the progress bar.

        We format numeric values (including floats in nested dicts) to strings using
        `_smart_format_value` so Rich's default `metrics_format` (e.g. `.3f`) is not
        applied on top of our desired representation.
        """
        # delegate to parent to get the standard metrics dict
        try:
            metrics = super().get_metrics(trainer, pl_module)
        except Exception:
            # If for some reason the parent doesn't implement it, fall back to an empty dict
            metrics = {}

        def _format_item(item):
            # format basic numeric types
            if isinstance(item, (int, float)):
                return _smart_format_value(item, max_sig=self._max_sig)
            if isinstance(item, dict):
                return {k: _format_item(v) for k, v in item.items()}
            return item

        return {k: _format_item(v) for k, v in metrics.items()}
