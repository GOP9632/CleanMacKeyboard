import Foundation

/// 從一連串「蓋子現在是開還是闔」裡認出「蓋子剛剛闔上」那一刻。
///
/// 這個規則值得有自己的型別，因為它用眼睛看不出來而且錯了很嚴重：認成狀態的
/// 話，接著外接螢幕闔蓋使用的人一進清潔模式就會被踢回待命，永遠擦不了那顆
/// 外接鍵盤；起點取錯的話，同一個人會遇到同一件事。真正去問 IOKit 的那一頭
/// 沒辦法寫測試，這一頭可以（見 `SystemMachineSignalSource`）。
struct LidCloseDetector {
    private var wasClosed: Bool

    /// 起點是「現在蓋子是什麼狀態」，不是「開著」。
    init(lidIsClosed: Bool) {
        wasClosed = lidIsClosed
    }

    /// 讀到一次蓋子狀態，回答這一次是不是剛剛闔上。
    ///
    /// 一直闔著只算第一次那一下。再開再闔才算下一次。
    mutating func observe(lidIsClosed: Bool) -> Bool {
        defer { wasClosed = lidIsClosed }
        return lidIsClosed && wasClosed == false
    }
}
