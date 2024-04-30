import SwiftUI

struct Splash: View {
    @Binding var isActive: Bool // Receive the isActive state binding

    var body: some View {
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            Text("Trackd")
                .font(.custom("AvenirNext-DemiBold", size: 50))
                .fontWeight(.bold)
                .foregroundColor(.green)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.2)]), startPoint: .leading, endPoint: .trailing)
                )
                .mask(Text("Trackd")
                    .font(.custom("AvenirNext-DemiBold", size: 50))
                    .fontWeight(.bold)
                )
        }
        .onAppear {
            // Set isActive to true after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isActive = true
            }
        }
    }
}




