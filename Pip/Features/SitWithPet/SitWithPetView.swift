import SwiftUI

struct SitWithPetView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("Close") { dismiss() } }
}
