import SwiftUI

/// Danh sách địa điểm người dùng đã lưu (bảng saved_places trên máy).
struct SavedView: View {
    let db: PlaceDatabase
    @State private var places: [Place] = []

    var body: some View {
        Group {
            if places.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40)).foregroundColor(.secondary)
                    Text("Chưa lưu địa điểm nào.\nMở một địa điểm và bấm \"Đã lưu\" để giữ lại tại đây.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(places) { place in
                        NavigationLink(destination: PlaceDetailView(place: place, db: db)) {
                            PlaceCardRow(place: place)
                        }
                    }
                    .onDelete { idx in
                        for i in idx { db.setSaved(placeID: places[i].id, saved: false) }
                        reload()
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationBarTitle("Đã lưu", displayMode: .large)
        .onAppear(perform: reload)
    }

    private func reload() {
        places = db.places(ids: Array(db.savedIDs()))
    }
}
