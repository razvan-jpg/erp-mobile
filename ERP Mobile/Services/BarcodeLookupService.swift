import Foundation

struct BarcodeProductLookup: Sendable {
    let name: String?
    let brand: String?
    let quantity: String?
    let imageURL: String?

    var resolvedName: String? {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let roName = trimmedName, !roName.isEmpty {
            if let trimmedBrand, !trimmedBrand.isEmpty,
               !roName.localizedCaseInsensitiveContains(trimmedBrand) {
                return "\(trimmedBrand) \(roName)"
            }
            return roName
        }

        if let trimmedBrand, !trimmedBrand.isEmpty {
            return trimmedBrand
        }

        return nil
    }
}

enum BarcodeLookupService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    static func lookup(barcode: String) async -> BarcodeProductLookup? {
        let normalized = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        guard !normalized.isEmpty else { return nil }

        if let result = await lookupOpenFacts(
            host: "world.openfoodfacts.org",
            barcode: normalized
        ) {
            return result
        }

        if let result = await lookupOpenFacts(
            host: "world.openproductsfacts.org",
            barcode: normalized
        ) {
            return result
        }

        return await lookupUPCItemDB(barcode: normalized)
    }

    private static func lookupOpenFacts(host: String, barcode: String) async -> BarcodeProductLookup? {
        guard let url = URL(string: "https://\(host)/api/v2/product/\(barcode).json?fields=product_name,product_name_ro,brands,quantity,image_front_url,image_url") else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(OpenFactsResponse.self, from: data)
            guard decoded.status == 1, let product = decoded.product else { return nil }

            let name = nonEmpty(product.productNameRo) ?? nonEmpty(product.productName)
            let brand = nonEmpty(product.brands)
            let quantity = nonEmpty(product.quantity)
            let imageURL = nonEmpty(product.imageFrontURL) ?? nonEmpty(product.imageURL)

            guard name != nil || brand != nil else { return nil }
            return BarcodeProductLookup(name: name, brand: brand, quantity: quantity, imageURL: imageURL)
        } catch {
            return nil
        }
    }

    private static func lookupUPCItemDB(barcode: String) async -> BarcodeProductLookup? {
        guard let encoded = barcode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.upcitemdb.com/prod/trial/lookup?upc=\(encoded)") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(UPCItemDBResponse.self, from: data)
            guard decoded.code == "OK", let item = decoded.items?.first else { return nil }
            let name = nonEmpty(item.title)
            let brand = nonEmpty(item.brand)
            guard name != nil || brand != nil else { return nil }
            return BarcodeProductLookup(name: name, brand: brand, quantity: nil, imageURL: nonEmpty(item.imageURL))
        } catch {
            return nil
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct OpenFactsResponse: Decodable {
    let status: Int
    let product: OpenFactsProduct?
}

private struct OpenFactsProduct: Decodable {
    let productName: String?
    let productNameRo: String?
    let brands: String?
    let quantity: String?
    let imageFrontURL: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNameRo = "product_name_ro"
        case brands, quantity
        case imageFrontURL = "image_front_url"
        case imageURL = "image_url"
    }
}

private struct UPCItemDBResponse: Decodable {
    let code: String
    let items: [UPCItemDBItem]?
}

private struct UPCItemDBItem: Decodable {
    let title: String?
    let brand: String?
    let images: [String]?

    var imageURL: String? {
        images?.first
    }
}
