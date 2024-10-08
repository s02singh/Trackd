
import SwiftUI


// Simple view struct to style and display the actual Google signin button
struct GoogleSigninBtn: View {
    var action: () -> Void
    
    var body: some View {
        HStack{
            Button {
                action()
            } label: {
                
                Image("GoogleSI")
                    .padding()
                
            }
            .frame(width: 50, height: 50)
        }
    }
}

struct GoogleSigninBtn_Previews: PreviewProvider {
    static var previews: some View {
        GoogleSigninBtn(action: {})
    }
}
