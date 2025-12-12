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

    def get_progress_bar_dict(self, trainer, pl_module):
        # delegate to parent to build the standard progress dict
        pb_dict = super().get_progress_bar_dict(trainer, pl_module)

        # Format each value if it's numeric
        for k, v in list(pb_dict.items()):
            pb_dict[k] = _smart_format_value(v, max_sig=self._max_sig)

        return pb_dict
