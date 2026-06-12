import SwiftUI

struct DesktopPetPresenter: View {
    @ObservedObject var store: ImagePetStore
    @State private var controller: DesktopPetWindowController?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                let controller = DesktopPetWindowController(store: store)
                self.controller = controller
                controller.setVisible(store.isDesktopPetVisible)
            }
            .onChange(of: store.isDesktopPetVisible) { isVisible in
                controller?.setVisible(isVisible)
            }
            .onDisappear {
                controller?.closeWindow()
                controller = nil
            }
    }
}
