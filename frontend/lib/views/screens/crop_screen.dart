// import 'package:flutter/material.dart';
// import 'package:frontend/core/themes/app_colors.dart';
//
// class CropScreen extends StatefulWidget {
//   const CropScreen({super.key});
//
//   @override
//   State<CropScreen> createState() => _CropScreenState();
// }
//
// class _CropScreenState extends State<CropScreen> {
//
//
//   @override
//   Widget build(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     return Scaffold(
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             Container(
//               width: double.infinity,
//               height: height/2.5,
//               decoration: BoxDecoration(
//                 color: Colors.greenAccent,
//                 gradient: LinearGradient(
//                   colors: [
//                     Color(0xFFD7F9F1),
//                     Color(0xFFBDE7F6),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//               child:Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   //Icon(Icons.camera_alt_outlined,size: 100,),
//                   Image.asset('assets/images/img.png',height: 100,width: 100,),
//                   SizedBox(height: 20,),
//                   Container(
//                     child: Text("Take a picture",style: TextStyle(color: AppColors.white,fontSize: 15,),),
//                     decoration: BoxDecoration(
//                       color: AppColors.primary,
//                       borderRadius: BorderRadius.circular(25)
//                     ),
//                     padding: EdgeInsets.symmetric(horizontal: 20,vertical: 10),
//                   )
//                 ],
//               ) ,
//
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CropScreen extends StatelessWidget {
  const CropScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 40% height image capture container
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green[300]!,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 64,
                      color: Colors.green[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Take an Image',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capture or upload maize leaf image\nto detect diseases',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        //ImagePicker().pickImage(source: ImageSource.camera);
                        _showSnackBar(context, 'Image capture feature coming soon!');
                      },
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tools Section
            Text(
              'Tools',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildToolCard(
                    icon: Icons.calculate,
                    title: 'Fertilizer\nCalculator',
                    color: Colors.white,
                    onTap: () => _showSnackBar(context, 'Fertilizer Calculator'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToolCard(
                    icon: Icons.bug_report,
                    title: 'Pesticide\nCalculator',
                    color: Colors.white,
                    onTap: () => _showSnackBar(context, 'Pesticide Calculator'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToolCard(
                    icon: Icons.show_chart,
                    title: 'Farming\nCalculator',
                    color: Colors.white,
                    onTap: () => _showSnackBar(context, 'Farming Calculator'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Library Section
            Text(
              'Library',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            _buildLibraryCard(
              icon: Icons.eco,
              title: 'Cultivation Tips',
              description: 'Best practices for growing healthy maize',
              color: Colors.green[50]!,
              onTap: () => _showSnackBar(context, 'Cultivation Tips'),
            ),
            const SizedBox(height: 12),
            _buildLibraryCard(
              icon: Icons.warning,
              title: 'Pests & Diseases',
              description: 'Identify and treat common maize diseases',
              color: Colors.orange[50]!,
              onTap: () => _showSnackBar(context, 'Pests & Diseases'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: Colors.green[700]),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: Colors.green[700]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}