extension CalendarSettings {
    public enum ValidationError: Error, Equatable {
        case dayStartHourOutOfRange(Int)
        case weekStartWeekdayOutOfRange(Int)
        case unknownTimeZone(String)
    }
}
