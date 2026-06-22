import sys
from pathlib import Path
sys.path.insert(0, str(Path("smart_fit_backend")))
from template_extractor import TemplateExtractor
from test_ocr_accuracy import benchmark_image, cfg

extractor = TemplateExtractor()
benchmark_image(
    extractor,
    cfg,
    "test_inbody_versions/inbody270.png",
    "InBody270"
)
