import 'dart:async';
import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/hospital_viewmodel.dart';
import 'package:mama_care/presentation/widgets/custom_text_field.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class HospitalView extends StatefulWidget {
  const HospitalView({Key? key}) : super(key: key);

  @override
  State<HospitalView> createState() => _HospitalViewState();
}

class _HospitalViewState extends State<HospitalView> {
  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    final hospitalViewModel =
        Provider.of<HospitalViewModel>(context, listen: false);
    hospitalViewModel.getUserCurrentLocation();
  }

  Future<void> _launchInBrowser(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HospitalViewModel>(
      builder: (context, hospitalViewModel, child) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: MamaCareAppBar(
          trailingWidget: const Icon(Icons.more_vert, color: Colors.white),
          title: "Hospitals",
          backgroundColor: Colors.transparent,
        ),
        body: GoogleMap(
          mapType: MapType.terrain,
          initialCameraPosition: _kGooglePlex,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          markers: _markers,
          myLocationEnabled: true,
          mapToolbarEnabled: false,
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.pinkAccent,
          child: const Icon(Icons.search, color: Colors.white),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Your Location",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        IconButton(
                          onPressed: () async {
                            final position = hospitalViewModel.currentPosition;
                            if (position != null) {
                              final cameraPosition = CameraPosition(
                                target: LatLng(position.latitude, position.longitude),
                                zoom: 14,
                              );

                              _markers.add(
                                Marker(
                                  markerId: const MarkerId('Home'),
                                  position: LatLng(position.latitude, position.longitude),
                                ),
                              );

                              final GoogleMapController controller = await _controller.future;
                              controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
                              hospitalViewModel.getHospitalList();
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.location_searching, color: Colors.pinkAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      controller: TextEditingController(),
                      hint: "Search Hospitals",
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _buildHospitalList(hospitalViewModel),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHospitalList(HospitalViewModel hospitalViewModel) {
    return ListView.builder(
      itemCount: hospitalViewModel.hospital?.results.length ?? 0,
      itemBuilder: (context, index) {
        final hospital = hospitalViewModel.hospital?.results[index];
        return ListTile(
          title: Text(hospital?.name ?? ''),
          subtitle: Text(hospital?.address ?? ''),
        );
      },
    );
  }
}
