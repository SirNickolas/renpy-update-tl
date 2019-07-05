module mvc.v.gtk.res;

version (GTKApplication):

import gtk.Image;

enum resourcePath(string relative) = `/io/github/SirNickolas/renpy-update-tl/` ~ relative;

private Image _createImageFromResource(string fullPath) {
    auto img = new Image;
    img.setFromResource(fullPath);
    return img;
}

Image createImageFromResource(string path)() {
    return _createImageFromResource(resourcePath!path);
}
