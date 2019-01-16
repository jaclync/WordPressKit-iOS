
/// Models a type of site.
public struct SiteSegment {
    public let identifier: Int64   // we use a numeric ID for segments; see p9wMUP-bH-612-p2 for discussion
    public let title: String
    public let subtitle: String
    public let icon: URL?
    public let iconColor: String?
    public let mobile: Bool

    public init(identifier: Int64, title: String, subtitle: String, icon: URL?, iconColor: String?, mobile: Bool) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.mobile = mobile
    }
}

extension SiteSegment {
    public static let blogSegmentIdentifier = Int64(1)
}

extension SiteSegment: Equatable {
    public static func ==(lhs: SiteSegment, rhs: SiteSegment) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

extension SiteSegment: Decodable {
    enum CodingKeys: String, CodingKey {
        case segmentId = "id"
        case segmentTypeTitle = "segment_type_title"
        case segmentTypeSubtitle = "segment_type_subtitle"
        case iconURL = "icon_URL"
        case iconColor = "icon_color"
        case mobile = "mobile"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try values.decode(Int64.self, forKey: .segmentId)
        title = try values.decode(String.self, forKey: .segmentTypeTitle)
        subtitle = try values.decode(String.self, forKey: .segmentTypeSubtitle)
        if let iconString = try values.decodeIfPresent(String.self, forKey: .iconURL) {
            icon = URL(string: iconString)
        } else {
            icon = nil
        }

        if let iconColorString = try values.decodeIfPresent(String.self, forKey: .iconColor) {
            var cleanIconColorString = iconColorString
            if iconColorString.hasPrefix("#") {
                cleanIconColorString = String(iconColorString.dropFirst(1))
            }

            iconColor = cleanIconColorString
        } else {
            iconColor = nil
        }

        mobile = try values.decode(Bool.self, forKey: .mobile)

    }
}

// MARK: - WordPressComServiceRemote (Site Segments)

/// Describes the errors that could arise when searching for site verticals.
///
/// - requestEncodingFailure:   unable to encode the request parameters.
/// - responseDecodingFailure:  unable to decode the server response.
/// - serviceFailure:           the service returned an unexpected error.
///
public enum SiteSegmentsError: Error {
    case requestEncodingFailure
    case responseDecodingFailure
    case serviceFailure
}

public enum SiteSegmentsResult {
    case success([SiteSegment])
    case failure(SiteSegmentsError)
}

public struct SiteSegmentsRequest: Encodable {
    public let locale: String

    public init(locale: String) {
        self.locale = locale
    }
}

public typealias SiteSegmentsServiceCompletion = (SiteSegmentsResult) -> Void

public extension WordPressComServiceRemote {
    func retrieveSegments(request: SiteSegmentsRequest, completion: @escaping SiteSegmentsServiceCompletion) {
        let endpoint = "segments"
        let remotePath = path(forEndpoint: endpoint, withVersion: ._2_0)

        let requestParameters: [String: AnyObject]
        do {
            requestParameters = try encodeRequestParameters(request: request)
        } catch {
            DDLogError("Failed to encode \(SiteSegmentsRequest.self) : \(error)")

            completion(.failure(SiteSegmentsError.requestEncodingFailure))
            return
        }

        wordPressComRestApi.GET(
            remotePath,
            parameters: requestParameters,
            success: { [weak self] responseObject, httpResponse in
                DDLogInfo("\(responseObject) | \(String(describing: httpResponse))")

                guard let self = self else {
                    return
                }

                do {
                    let response = try self.decodeResponse(responseObject: responseObject)
                    let validContent = self.validSegments(response)
                    completion(.success(validContent))
                } catch {
                    DDLogError("Failed to decode \([SiteVertical].self) : \(error.localizedDescription)")
                    completion(.failure(SiteSegmentsError.responseDecodingFailure))
                }
            },
            failure: { error, httpResponse in
                DDLogError("\(error) | \(String(describing: httpResponse))")
                completion(.failure(SiteSegmentsError.serviceFailure))
        })
    }
}

private extension WordPressComServiceRemote {
    private func encodeRequestParameters(request: SiteSegmentsRequest) throws -> [String: AnyObject] {

        let encoder = JSONEncoder()

        let jsonData = try encoder.encode(request)
        let serializedJSON = try JSONSerialization.jsonObject(with: jsonData, options: [])

        let requestParameters: [String: AnyObject]
        if let jsonDictionary = serializedJSON as? [String: AnyObject] {
            requestParameters = jsonDictionary
        } else {
            requestParameters = [:]
        }

        return requestParameters
    }

    private func decodeResponse(responseObject: AnyObject) throws -> [SiteSegment] {
        let decoder = JSONDecoder()
        let data = try JSONSerialization.data(withJSONObject: responseObject, options: [])
        let response = try decoder.decode([SiteSegment].self, from: data)

        return response
    }

    private func validSegments(_ allSegments: [SiteSegment]) -> [SiteSegment] {
        return allSegments.filter {
            return $0.mobile == true
        }
    }
}
