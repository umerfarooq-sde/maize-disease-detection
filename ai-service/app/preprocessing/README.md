# Shared preprocessing boundary

Phase 8 contains no image processing implementation. Phase 9 must choose one shared,
versioned package imported by both this service and `ml-training`; never implement
separate training and inference pipelines. Validation, decoding, color conversion,
segmentation, cropping, resizing, normalization and tensor conversion belong there.
