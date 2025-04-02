import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:mama_care/utils/asset_helper.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/suggested_food_viewmodel.dart';

class SuggestedFoodScreen extends StatelessWidget {
  const SuggestedFoodScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SuggestedFoodViewModel>(context);

    return Scaffold(
      appBar: MamaCareAppBar(
        trailingWidget: const Icon(Icons.more_vert),
        title: 'Suggested Food',
      ),
      body: ListView.builder(
        itemCount: viewModel.foodData.length,
        itemBuilder: (context, index) {
          final data = viewModel.foodData[index];
          return ListTile(
            leading: Container(
              decoration: BoxDecoration(
                color: const Color(0xffFFCDD2),
                borderRadius: BorderRadius.circular(10),
              ),
              width: 10.w,
              height: 10.w,
              child: SvgPicture.asset(
                AssetsHelper.seedSvg,
                color: Colors.pink,
              ),
            ),
            title: Text(data['food_name']),
            subtitle: Text('${data['description'].substring(0, 50)}...'),
          );
        },
      ),
    );
  }
}
