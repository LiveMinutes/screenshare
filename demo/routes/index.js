var title = 'Screen sharing WebRTC / Canvas';
exports.emit = function(req, res){
    res.render('screen_emit.html', { title: title, room: req.params.room });
};

exports.receive = function(req, res){
    res.render('screen_down.html', { title: title, room: req.params.room});
};

exports.screenshot = function(req, res){
    res.render('screen_shot.html', { title: title, room: req.params.room});
};