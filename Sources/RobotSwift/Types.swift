import CoreGraphics
import Foundation

public struct RobotPoint: Codable, Equatable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

public struct RobotSize: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct RobotRect: Codable, Equatable, Sendable {
    public var origin: RobotPoint
    public var size: RobotSize

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.origin = RobotPoint(x: x, y: y)
        self.size = RobotSize(width: width, height: height)
    }

    public init(_ rect: CGRect) {
        self.init(
            x: Int(rect.origin.x.rounded(.towardZero)),
            y: Int(rect.origin.y.rounded(.towardZero)),
            width: Int(rect.width.rounded(.towardZero)),
            height: Int(rect.height.rounded(.towardZero))
        )
    }

    public var x: Int { origin.x }
    public var y: Int { origin.y }
    public var width: Int { size.width }
    public var height: Int { size.height }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct RobotProcess: Codable, Equatable, Sendable {
    public var pid: Int32
    public var name: String
    public var path: String?

    public init(pid: Int32, name: String, path: String?) {
        self.pid = pid
        self.name = name
        self.path = path
    }
}

public struct RobotWindow: Codable, Equatable, Sendable {
    public var id: UInt32
    public var ownerPID: Int32
    public var ownerName: String
    public var title: String
    public var bounds: RobotRect

    public init(id: UInt32, ownerPID: Int32, ownerName: String, title: String, bounds: RobotRect) {
        self.id = id
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.title = title
        self.bounds = bounds
    }
}

public enum RobotError: LocalizedError, Equatable {
    case invalidArgument(String)
    case permissionDenied(String)
    case unsupported(String)
    case notFound(String)
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArgument(let message),
             .permissionDenied(let message),
             .unsupported(let message),
             .notFound(let message),
             .operationFailed(let message):
            message
        }
    }
}
