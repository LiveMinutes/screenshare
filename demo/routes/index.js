var fs = require('fs');
var path = require('path');

var title = 'Screen sharing WebRTC / Canvas';
exports.emit = function(req, res){
    res.render('screen_emit.html', { title: title, room: req.params.room });
};

exports.receive = function(req, res){
    res.render('screen_down.html', { title: title, room: req.params.room});
};

exports.screenshot = function(req, res){
	var file = req.files.blob,
	 	roomScreenshotsPath = path.resolve('./public/images/' + req.params.room),
	 	newFilename = file.name + '-' + new Date().getTime() + '.jpeg',
	 	newPath = path.join(roomScreenshotsPath, newFilename);

	if(!fs.existsSync(roomScreenshotsPath)) {
		console.log('Creating room screenshots dest folder', newPath);
		fs.mkdirSync(roomScreenshotsPath);
	}

    fs.rename(file.path, newPath, function(errRename) {
		if (errRename) {
    		console.error(errRename);
			return res.send({
				error: errRename
			});
		}

		return res.send({
			success: true,
			fileName: newFilename
		});
	});
};