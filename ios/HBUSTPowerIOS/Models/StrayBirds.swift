import Foundation

/// Lines from Tagore's *Stray Birds* (1916), in 郑振铎's 1922 Chinese translation. Both the original and that
/// translation are out of copyright. Shown once per launch in the 紫鸟紫 theme, always with the attribution.
enum StrayBirds {
    static let attribution = "摘自《飞鸟集》· 泰戈尔"

    static let lines = [
        "夏天的飞鸟，飞到我的窗前唱歌，又飞去了。",
        "世界上的一队小小的漂泊者呀，请留下你们的足印在我的文字里。",
        "如果你因失去了太阳而流泪，那么你也将失去群星了。",
        "我今晨坐在窗前，世界如一个路人似的，停留了一会，向我点点头又走过去了。",
        "休息与工作的关系，正如眼睑与眼睛的关系。",
        "瀑布歌唱道：我得到自由时便有了歌声了。",
        "我的心把她的波浪在世界的海岸上冲激着，以热泪在上边写着她的题记：我爱你。",
        "群星不怕显得像萤火那样。",
        "使生如夏花之绚烂，死如秋叶之静美。",
        "这寡独的黄昏，幕着雾与雨，我在我的心的孤寂里，感觉到它的叹息。",
        "我们把世界看错了，反说它欺骗我们。",
        "夜秘密地把花开放了，却让白日去领受谢词。",
        "小草呀，你的足步虽小，但是你拥有你足下的土地。",
        "错误经不起失败，但是真理却不怕失败。",
        "只管走过去，不必逗留着采了花朵来保存，因为一路上花朵自会继续开放的。"
    ]

    /// One line per launch, so the home screen greets you with something new each time you open the app.
    static let ofThisLaunch = lines.randomElement() ?? lines[0]

    /// Used when the reader taps for another one.
    static func line(after current: String) -> String {
        guard let index = lines.firstIndex(of: current) else { return ofThisLaunch }
        return lines[(index + 1) % lines.count]
    }
}
