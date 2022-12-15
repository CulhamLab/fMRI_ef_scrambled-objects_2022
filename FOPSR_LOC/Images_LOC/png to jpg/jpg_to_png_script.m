%to convert files from .jpg to .png
images_jpg = dir ('*.jpg');
images_png = dir ('*.png');

image_names = {images_png.name}
num_images = length (image_names)

for k=1:numel(image_names)
    file=image_names{k}
      new_file=strrep(file,'.png','.jpg');
  im=imread(file);
  imwrite(im,new_file);
end

