import Foundation

private struct ImageLookupCandidate {
    let url: String
    let score: Int
}

enum ProductImageLookupService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    private static let searchHosts = [
        "world.openfoodfacts.org",
        "world.openproductsfacts.org",
        "world.openbeautyfacts.org"
    ]

    static func findBestImage(name: String, barcode: String?) async -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBarcode = normalizedBarcode(barcode)
        guard !trimmedName.isEmpty || normalizedBarcode != nil else { return nil }

        var candidates: [ImageLookupCandidate] = []

        if let normalizedBarcode {
            if let lookup = await BarcodeLookupService.lookup(barcode: normalizedBarcode),
               let imageURL = lookup.imageURL {
                candidates.append(ImageLookupCandidate(url: imageURL, score: 120))
            }
        }

        if !trimmedName.isEmpty {
            for host in searchHosts {
                let results = await searchOpenFacts(host: host, query: trimmedName)
                for product in results {
                    guard let imageURL = preferredImageURL(from: product) else { continue }
                    var score = 40 + nameMatchScore(product.productName ?? "", query: trimmedName)
                    if let normalizedBarcode,
                       let code = product.code?.trimmingCharacters(in: .whitespacesAndNewlines),
                       BarcodeMatching.normalize(code) == normalizedBarcode {
                        score += 80
                    }
                    candidates.append(ImageLookupCandidate(url: imageURL, score: score))
                }
            }
        }

        if let normalizedBarcode, trimmedName.isEmpty {
            for host in searchHosts {
                let results = await searchOpenFacts(host: host, query: normalizedBarcode)
                for product in results {
                    guard let imageURL = preferredImageURL(from: product) else { continue }
                    var score = 60
                    if let code = product.code?.trimmingCharacters(in: .whitespacesAndNewlines),
                       BarcodeMatching.normalize(code) == normalizedBarcode {
                        score += 80
                    }
                    candidates.append(ImageLookupCandidate(url: imageURL, score: score))
                }
            }
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.url.count > rhs.url.count
            }
            .first?
            .url
    }

    private static func normalizedBarcode(_ barcode: String?) -> String? {
        guard let barcode else { return nil }
        let normalized = BarcodeMatching.normalize(
            barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return normalized.isEmpty ? nil : normalized
    }

    private static func searchOpenFacts(host: String, query: String) async -> [OpenFactsSearchProduct] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(host)/cgi/search.pl?search_terms=\(encoded)&json=true&page_size=8&fields=code,product_name,image_front_url,image_url") else {
            return []
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            let decoded = try JSONDecoder().decode(OpenFactsSearchResponse.self, from: data)
            return decoded.products ?? []
        } catch {
            return []
        }
    }

    private static func preferredImageURL(from product: OpenFactsSearchProduct) -> String? {
        nonEmpty(product.imageFrontURL) ?? nonEmpty(product.imageURL)
    }

    private static func nameMatchScore(_ candidate: String, query: String) -> Int {
        let normalizedCandidate = normalizeForMatch(candidate)
        let normalizedQuery = normalizeForMatch(query)
        guard !normalizedCandidate.isEmpty, !normalizedQuery.isEmpty else { return 0 }

        if normalizedCandidate == normalizedQuery { return 40 }
        if normalizedCandidate.contains(normalizedQuery) || normalizedQuery.contains(normalizedCandidate) {
            return 28
        }

        let candidateWords = Set(normalizedCandidate.split(separator: " ").map(String.init))
        let queryWords = Set(normalizedQuery.split(separator: " ").map(String.init))
        let overlap = candidateWords.intersection(queryWords).count
        return min(24, overlap * 6)
    }

    private static func normalizeForMatch(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct OpenFactsSearchResponse: Decodable {
    let products: [OpenFactsSearchProduct]?
}

private struct OpenFactsSearchProduct: Decodable {
    let code: String?
    let productName: String?
    let imageFrontURL: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case imageFrontURL = "image_front_url"
        case imageURL = "image_url"
    }
}
