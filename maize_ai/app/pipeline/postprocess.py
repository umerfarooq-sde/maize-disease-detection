def confidence_filter(result, threshold=0.6):

    if result["confidence"] < threshold:
        return {
            "prediction": "Uncertain",
            "confidence": result["confidence"]
        }

    return result