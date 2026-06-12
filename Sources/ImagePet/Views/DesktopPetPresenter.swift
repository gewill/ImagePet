import SwiftUI

struct DesktopPetPresenter: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                store.attachDesktopPetControllerIfNeeded()
            }
    }
}
