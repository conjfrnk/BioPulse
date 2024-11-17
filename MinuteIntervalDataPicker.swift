//
//  MinuteIntervalDataPicker.swift
//  BioPulse
//
//  Created by Connor Frank on 11/15/24.
//

import SwiftUI
import UIKit

struct MinuteIntervalDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    var minuteInterval: Int = 5

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.minuteInterval = minuteInterval
        picker.preferredDatePickerStyle = .wheels
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = normalizeDate(selection)
        uiView.minuteInterval = minuteInterval
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func normalizeDate(_ date: Date) -> Date {
        var components = Calendar.current.dateComponents([.hour, .minute], from: date)
        components.year = 2000
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? date
    }

    class Coordinator: NSObject {
        var parent: MinuteIntervalDatePicker

        init(_ parent: MinuteIntervalDatePicker) {
            self.parent = parent
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            parent.selection = parent.normalizeDate(sender.date)
        }
    }
}
