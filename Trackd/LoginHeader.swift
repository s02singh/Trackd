
import SwiftUI


// Stylized header for LoginScreen. Idea was to potentially change it but we liked it as is.
struct LoginHeader: View {
    var body: some View {
        VStack {
            Text("Trackd")
                .font(.custom("AvenirNext-DemiBold", size: 40))
                .fontWeight(.bold)
                .foregroundColor(.green)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.2)]), startPoint: .leading, endPoint: .trailing)
                )
                .mask(Text("Trackd")
                    .font(.custom("AvenirNext-DemiBold", size: 40))
                    .fontWeight(.bold)
                )
        }
    }
}

struct LoginHeader_Previews: PreviewProvider {
    static var previews: some View {
        LoginHeader()
    }
}
