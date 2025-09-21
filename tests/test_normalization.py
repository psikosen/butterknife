from butterknife.normalization import normalize_candidate


def test_normalize_candidate_resolves_relative_url():
    page = "https://example.com/articles/index.html"
    candidate = "../images/photo.jpg"
    normalized = normalize_candidate(page, candidate)
    assert normalized == "https://example.com/images/photo.jpg"


def test_normalize_candidate_sorts_query_parameters():
    page = "https://example.com/"
    candidate = "https://example.com/image.jpg?b=2&a=1"
    normalized = normalize_candidate(page, candidate)
    assert normalized == "https://example.com/image.jpg?a=1&b=2"


def test_normalize_candidate_rejects_data_urls():
    page = "https://example.com/"
    candidate = "data:image/png;base64,AAAA"
    assert normalize_candidate(page, candidate) is None
