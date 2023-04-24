import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photoprism/api/api.dart';
import 'package:photoprism/api/db_api.dart';
import 'package:photoprism/common/hexcolor.dart';
import 'package:photoprism/model/filter_photos.dart';
import 'package:photoprism/model/photoprism_model.dart';
import 'package:photoprism/pages/album_detail_view.dart';
import 'package:provider/provider.dart';

class AlbumsPage extends StatelessWidget {
  const AlbumsPage({Key? key}) : super(key: key);

  static String getAlbumPreviewUrl(BuildContext context, int index) {
    final PhotoprismModel model = Provider.of<PhotoprismModel>(context);
    if (model.albums != null &&
        model.albums!.length - 1 >= index &&
        model.albumCounts != null &&
        model.albumCounts![model.albums![index].uid] != null &&
        model.config != null) {
      return model.photoprismUrl +
          '/api/v1/albums/' +
          model.albums![index].uid +
          '/t/' +
          model.config!.previewToken! +
          '/tile_500';
    } else {
      return 'https://raw.githubusercontent.com/photoprism/photoprism-mobile/master/assets/emptyAlbum.jpg';
    }
  }

  Future<void> _showCreateAlbumDialog(BuildContext context) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nameTextFieldController =
        TextEditingController();
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Create album'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: nameTextFieldController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Name',
                ),
                validator: (String? text) {
                  if (text == null || text.isEmpty) {
                    return 'Can\'t be empty';
                  }
                  return null;
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: const Text('Create'),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    createAlbum(context, nameTextFieldController.text);
                  }
                },
              )
            ],
          );
        });
  }

  Future<void> createAlbum(BuildContext context, String name) async {
    final PhotoprismModel model =
        Provider.of<PhotoprismModel>(context, listen: false);
    model.photoprismLoadingScreen
        .showLoadingScreen('create_album'.tr() + '...');
    final String uuid = await apiCreateAlbum(name, model);

    if (uuid == '-1') {
      await model.photoprismLoadingScreen.hideLoadingScreen();
      model.photoprismMessage.showMessage('Creating album failed.');
    } else {
      await apiUpdateDb(model);
      model.albumUid = uuid;
      model.updatePhotosSubscription();
      await model.photoprismLoadingScreen.hideLoadingScreen();
    }
  }

  String _albumCount(PhotoprismModel model, int index) {
    if (index >= model.albums!.length) {
      return '0';
    }
    final String? uid = model.albums![index].uid;
    if (model.albumCounts!.containsKey(uid)) {
      return model.albumCounts![uid!].toString();
    }
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    final PhotoprismModel model = Provider.of<PhotoprismModel>(context);
    return Scaffold(
        appBar: AppBar(
          title: const Text('PhotoPrism'),
          backgroundColor: HexColor(model.applicationColor!),
          automaticallyImplyLeading: false,
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'create_album'.tr(),
              onPressed: () {
                _showCreateAlbumDialog(context);
              },
            ),
          ],
        ),
        body: RefreshIndicator(
            child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: <PointerDeviceKind>{
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: OrientationBuilder(
                    builder: (BuildContext context, Orientation orientation) {
                  if (model.dbTimestamps!.isEmpty) {
                    apiUpdateDb(model);
                    return const Text('',
                        key: ValueKey<String>('albumsGridView'));
                  }
                  return GridView.builder(
                      key: const ValueKey<String>('albumsGridView'),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            orientation == Orientation.portrait ? 2 : 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      padding: const EdgeInsets.all(10),
                      itemCount: model.albums!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return GestureDetector(
                            onTap: () {
                              model.albumUid = model.albums![index].uid;
                              model.filterPhotos = FilterPhotos();
                              model.updatePhotosSubscription();
                              Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (BuildContext ctx) =>
                                          AlbumDetailView(model.albums![index],
                                              index, context)));
                            },
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: GridTile(
                                  child: CachedNetworkImage(
                                    cacheKey: model.albums!.length - 1 >= index
                                        ? 'album-${model.albums![index].uid}'
                                        : 'album-none',
                                    httpHeaders:
                                        model.photoprismAuth.getAuthHeaders(),
                                    imageUrl:
                                        getAlbumPreviewUrl(context, index),
                                    placeholder:
                                        (BuildContext context, String url) =>
                                            Container(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .background),
                                    errorWidget: (BuildContext context,
                                            String url, Object? error) =>
                                        const Icon(Icons.error),
                                  ),
                                  footer: GestureDetector(
                                    child: GridTileBar(
                                      backgroundColor: Colors.black45,
                                      trailing: Text(
                                        _albumCount(model, index),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      title: _GridTitleText(
                                          model.albums!.length - 1 >= index
                                              ? model.albums![index].title
                                              : ''),
                                    ),
                                  ),
                                )));
                      });
                })),
            onRefresh: () async {
              return apiUpdateDb(model);
            }));
  }
}

class _GridTitleText extends StatelessWidget {
  const _GridTitleText(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text!),
    );
  }
}
