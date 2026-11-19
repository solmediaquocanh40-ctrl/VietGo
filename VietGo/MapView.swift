import SwiftUI
import MapKit

/// Bản đồ chấm địa điểm (nền bản đồ của Apple — cần mạng; lớp dữ liệu điểm
/// vẫn là dữ liệu offline trong máy). Chạm chấm để xem thẻ tóm tắt.
struct MapView: View {
    let places: [Place]
    let db: PlaceDatabase
    @State private var region: MKCoordinateRegion
    @State private var selected: Place?

    init(places: [Place], db: PlaceDatabase) {
        self.places = places
        self.db = db
        let center = places.first.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            ?? CLLocationCoordinate2D(latitude: 11.9404, longitude: 108.4583) // Đà Lạt
        _region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, showsUserLocation: true,
                annotationItems: Array(places.prefix(300))) { place in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: place.lat,
                                                                  longitude: place.lon)) {
                    Button(action: { selected = place }) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(selected?.id == place.id ? .green : .red)
                            .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                    }
                }
            }
            .edgesIgnoringSafeArea(.bottom)

            if let sel = selected {
                NavigationLink(destination: PlaceDetailView(place: sel, db: db)) {
                    HStack(spacing: 12) {
                        PlacePhoto(place: sel, height: 56)
                            .frame(width: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sel.name).font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary).lineLimit(1)
                            Text(sel.categoryName).font(.caption).foregroundColor(.secondary)
                            StatusLine(place: sel)
                        }
                        Spacer()
                        ContactIconRow(place: sel)
                    }
                    .padding(10)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 6)
                    .padding()
                }
            }
        }
        .navigationBarTitle("Bản đồ", displayMode: .inline)
    }
}
