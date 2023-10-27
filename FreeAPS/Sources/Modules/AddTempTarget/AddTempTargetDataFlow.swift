enum AddTempTarget {
    enum Config {}
}

protocol AddTempTargetProvider: Provider {
    func tempTargets(hours: Int) -> [TempTarget]
    func tempTarget() -> TempTarget?
}
