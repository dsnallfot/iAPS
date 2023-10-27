enum ManualTempBasal {
    enum Config {}
}

protocol ManualTempBasalProvider: Provider {
    var suggestion: Suggestion? { get }
    func pumpSettings() -> PumpSettings
}
