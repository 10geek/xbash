$(function() {
	$('.asciinema-player').each(function() {
		var elem = $(this);
		var params = {
			autoPlay: elem.attr('data-autoplay'),
			idleTimeLimit: elem.attr('data-idle-time-limit'),
			theme: 'common'
		};
		params.autoPlay = params.autoPlay !== undefined && (params.autoPlay === '' || !!parseInt(params.autoPlay));
		if(params.idleTimeLimit !== undefined)
			params.idleTimeLimit = parseFloat(params.idleTimeLimit);
		asciinema.player.js.CreatePlayer(this, elem.attr('data-src'), params);
	});
});
