import AppKit
import ImageIO

enum PetPose: Int, CaseIterable {
    case idle, runRight, runLeft, wave, happy, sleep, think, hurry, curious

    var frameCount: Int { [6, 8, 8, 4, 5, 8, 6, 6, 6][rawValue] }
    var title: String {
        ["待机", "向右跑", "向左跑", "招手", "开心", "睡觉", "思考", "小跑", "好奇"][rawValue]
    }
}

final class SpriteAtlas {
    static let laptopColumns = 16
    static let laptopFrameCount = 64
    private var images: [PetPose: [CGImage]] = [:]
    private var laptopImages: [CGImage] = []

    init() throws {
        guard let url = Bundle.main.url(forResource: "kurisu", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil),
              sheet.width == 1536, sheet.height == 1872 else {
            throw NSError(domain: "Kurisu", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "找不到完整的 Kurisu 动画素材，请重新构建应用。"])
        }
        for pose in PetPose.allCases {
            images[pose] = (0..<pose.frameCount).compactMap { index in
                sheet.cropping(to: CGRect(x: index * 192, y: pose.rawValue * 208,
                                         width: 192, height: 208))
            }
        }
        // Rest frames are normalized individually as the head grows during
        // sitting down. The same images also supply AppModel's alpha maps.
        guard let restURL = Bundle.main.url(forResource: "kurisu-rest", withExtension: "png"),
              let restSource = CGImageSourceCreateWithURL(restURL as CFURL, nil),
              let restSheet = CGImageSourceCreateImageAtIndex(restSource, 0, nil),
              restSheet.width == 1536, restSheet.height == 208 else {
            throw NSError(domain: "Kurisu", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "缺少统一尺寸的休息动作素材，请重新构建完整应用。"])
        }
        images[.sleep] = (0..<8).compactMap { index in
            restSheet.cropping(to: CGRect(x: index * 192, y: 0, width: 192, height: 208))
        }
        guard let laptopURL = Bundle.main.url(forResource: "kurisu-laptop", withExtension: "png"),
              let laptopSource = CGImageSourceCreateWithURL(laptopURL as CFURL, nil),
              let laptopSheet = CGImageSourceCreateImageAtIndex(laptopSource, 0, nil),
              laptopSheet.width == 3072, laptopSheet.height == 832 else {
            throw NSError(domain: "Kurisu", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "缺少电脑动作素材，请重新构建完整应用。"])
        }
        laptopImages = (0..<Self.laptopFrameCount).compactMap { index in
            laptopSheet.cropping(to: CGRect(x: (index % Self.laptopColumns) * 192,
                                           y: (index / Self.laptopColumns) * 208,
                                           width: 192, height: 208))
        }
    }

    func image(_ pose: PetPose, frame: Int) -> CGImage {
        let frames = images[pose]!
        return frames[max(0, frame) % frames.count]
    }

    func laptopImage(frame: Int) -> CGImage {
        laptopImages[min(laptopImages.count - 1, max(0, frame))]
    }
}
