import asyncio

from app.services.circular_parser import CircularParser


def test_extract_store_name_various_fields():
    parser = CircularParser()

    samples = [
        ({"merchant": "Kroger"}, "Kroger"),
        ({"merchant_name": "Walmart"}, "Walmart"),
        ({"store_name": "Target - 123"}, "Target - 123"),
        ({"retailer": "Costco"}, "Costco"),
        ({"flyer": {"merchant": "Publix"}}, "Publix"),
        ({"merchant": "" , "retailer": ""}, None),
    ]

    for item, expected in samples:
        extracted = parser._extract_store_name(item)
        assert (extracted == expected) or (extracted is None and expected is None)


def test_parse_flipp_item_fallback_to_local_deals():
    parser = CircularParser()

    item = {"name": "Milk", "price_text": "$3.99"}
    parsed = parser.parse_flipp_item(item)
    assert parsed is not None
    # store_chain should be 'Local Deals' when nothing else provided
    assert parsed.store_chain == "Local Deals"
