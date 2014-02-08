id = 0;
liNo = 0;
clipPlaying = -1;
//isOriginal = 1;
videoData = new Object();

// Called automatically when JavaScript client library is loaded.
function onClientLoad() {
    gapi.client.load('youtube', 'v3', onYouTubeApiLoad);
}

// Called automatically when YouTube API interface is loaded (see line 9).
function onYouTubeApiLoad() {
    gapi.client.setApiKey('AIzaSyCR5In4DZaTP6IEZQ0r1JceuvluJRzQNLE');
}

function search() {
	var q = $('#query').val();
    // Use the JavaScript client library to create a search.list() API call.
    var request = gapi.client.youtube.search.list({
        part: 'snippet',
		q: q,
        type: 'video',
        maxResults: 10
    });
    
    // Send the request to the API server,
    // and invoke onSearchRepsonse() with the response.
    request.execute(onSearchResponse);
}

// Called automatically with the response of the YouTube API request.
function onSearchResponse(response) {
	  var str = response.result;
	  var items = str.items || [];
	  var html = [];
	  for (var i = 0; i < 10; i++) {
		var item = items[i];
		var videoId = item.id.videoId;
        if (videoId) {
            var img = item.snippet.thumbnails.medium.url; 
            var name = item.snippet.title;
            var l = '<div class="col-xs-6 col-sm-12 col-md-6"><a href=\"#\" class=\"thumbnail\" onclick=\"initVideo(\'' + videoId + '\')\"><img src=\"' + img + '\"></img><p href=\"#\">' + name + '</p></a></div>';
            html.push(l);
        }
	  }
	  document.getElementById('videos').innerHTML = html.join('');
}

function initVideo(videoId) {

    var url = "http://gdata.youtube.com/feeds/api/videos/" + videoId + "?v=2&alt=jsonc&prettyprint=true";

    $.get(url, function(data) { 
        var duration = data["data"]["duration"];
        $("#progress_bar").slider({
            value: 0,
            min: 0,
            max: duration,
            change: function(event, ui){
                ytplayer.seekTo(ui.value, 1);
            }
        }); 
                /*
                The allowSeekAhead parameter determines whether the player will make a new request to the server if the seconds parameter specifies a time outside of the currently buffered video data.

                We recommend that you set this parameter to false while the user drags the mouse along a video progress bar and then set it to true when the user releases the mouse. This approach lets a user scroll to different points of a video without requesting new video streams by scrolling past unbuffered points in the video. When the user releases the mouse button, the player advances to the desired point in the video and requests a new video stream if necessary.
                */
    });
    loadVideo(videoId, 0);
}
function loadVideo(videoId, start) {
    if(ytplayer) {
        ytplayer.loadVideoById({
            'videoId': videoId,
            'startSeconds': start 
        });
        id = videoId;
    }
}
function loadVideo2(videoId, start, end, liNo) {
    if(ytplayer2) {
        clipPlaying = liNo;
        /*
        ytplayer2.loadVideoById({
            'videoId': videoId,
            'startSeconds': start
            //'endSeconds': end
        });
        */
        ytplayer2.loadVideoById({
            'videoId': videoId,
            'startSeconds': start 
        });
        /*
        ytplayer2.seekTo(start, 1);
        */
        id = videoId;

        var url = "http://gdata.youtube.com/feeds/api/videos/" + videoId + "?v=2&alt=jsonc&prettyprint=true";
        var minTime;   
        var maxTime; 
        $.get(url, function(data) { 
            var duration = data["data"]["duration"];

            if (start <= 30) {
                minTime = 0; 
            }
            else {
                minTime = start - 30;
            }
            if (duration - end <= 30) {
                maxTime = duration; 
            }
            else {
                maxTime = end + 30;
            }
            $("#slider-range").slider({
                range: true,
                min: minTime,
                max: maxTime,
                values: [start, end],
                step: 1,
                slide: changeTime,
                change: function(event, ui){
                    playSelected(videoId); 
                    changeTime(event, ui);
                    //isOriginal = 0;
                }
            }); 
        });
    }
}

function changeTime(event, ui){
        var val0 = $("#slider-range").slider("values", 0);
        var val1 = $("#slider-range").slider("values", 1);
        var l = '<a onclick=\"loadVideo2(\'' + id + '\',' + val0 + ',' + val1 + ',' + clipPlaying + ')\" href=\"#\">' + val0 + '-' + val1 + '</a>';

        $("#a" + clipPlaying).html(l);
}

function playSelected(id) {
      if(ytplayer2 && (clipPlaying != -1)) {
        var videoId = id;
        var start = $("#slider-range").slider("values", 0);
        var end = $("#slider-range").slider("values", 1);

        videoData[clipPlaying]["videoStart"] = start;
        videoData[clipPlaying]["videoEnd"] = end;
        ytplayer2.seekTo(start, 1);
        /*
        ytplayer2.loadVideoById({
            'videoId': videoId,
            'startSeconds': start,
            'endSeconds': end
        });
        */
    }
}


/*
* Chromeless player has no controls.
*/

// Update a particular HTML element with a new value
function updateHTML(elmId, value) {
    var elem = document.getElementById(elmId);

    if(typeof elem !== 'undefined' && elem !== null) {
        document.getElementById(elmId).innerHTML = value;
    }
}
      
// This function is called when an error is thrown by the player
function onPlayerError(errorCode) {
    alert("An error occured of type:" + errorCode);
}
      
// This function is called when the player changes state
function onPlayerStateChange(newState) {
    updateHTML("playerState", newState);
}
      
function onPlayerError2(errorCode2) {
    alert("An error occured of type:" + errorCode2);
}
      

// Display information about the current state of the player
function updatePlayerInfo() {
    // Also check that at least one function exists since when IE unloads the
    // page, it will destroy the SWF before clearing the interval.
    if(typeof ytplayer.getDuration !== 'undefined')
    {
        if(ytplayer && ytplayer.getDuration()){
            updateHTML("selectedTime", $("#progress_bar").slider("value"));
            updateHTML("videoDuration", ytplayer.getDuration());
            updateHTML("videoCurrentTime", ytplayer.getCurrentTime());
            updateHTML("volume", ytplayer.getVolume());
        }
    }
}

function updatePlayerInfo2() {
    if(typeof ytplayer2.getDuration !== 'undefined') {
        if (typeof videoData[clipPlaying] !== 'undefined' && videoData[clipPlaying] !== null){
            if (videoData[clipPlaying]["videoEnd"] < ytplayer2.getCurrentTime()) {
                stopVideo2();
            }
            updateHTML("videoDuration2", ytplayer2.getDuration());
            updateHTML("clipDuration", videoData[clipPlaying]["videoEnd"]);
            updateHTML("videoCurrentTime2", ytplayer2.getCurrentTime());
            updateHTML("videoCurrentTime3", ytplayer2.getCurrentTime());
        }
    }
}
      
      
function playVideo() {
    if (ytplayer && ytplayer.getPlayerState()!==-1) {
        ytplayer.playVideo();
    }
}
      
function pauseVideo() {
    if (ytplayer) {
        ytplayer.pauseVideo();
    }
}
      
function muteVideo() {
    if(ytplayer) {
        ytplayer.mute();
    }
}
      
function unMuteVideo() {
    if(ytplayer) {
        ytplayer.unMute();
    }
}

function stopVideo() {
    if(ytplayer) {
        ytplayer.stopVideo();
    }
}

function playFromStart2() {
    if (ytplayer2) {
        videoId = id;
        var url = "http://gdata.youtube.com/feeds/api/videos/" + videoId + "?v=2&alt=jsonc&prettyprint=true";
        $.get(url, function(data) { 
            var duration = data["data"]["duration"];

            $("#progress_bar_2").slider({
                value: 0,
                min: 0,
                max: duration,
                change: function(event, ui){
                    ytplayer2.seekTo(ui.value, 1);
                }
            }); 
            ytplayer2.loadVideoById({
                'videoId': videoId,
                'startSeconds': 0 
            });
        });
    }
}

function playVideo2() {
    if (ytplayer2 && ytplayer2.getPlayerState()!==-1) {
        ytplayer2.playVideo();
    }
}
      
function pauseVideo2() {
    if (ytplayer2) {
        ytplayer2.pauseVideo();
    }
}
      
function muteVideo2() {
    if(ytplayer2) {
        ytplayer2.mute();
    }
}
      
function unMuteVideo2() {
    if(ytplayer2) {
        ytplayer2.unMute();
    }
}

function stopVideo2() {
    if(ytplayer2) {
        ytplayer2.stopVideo();
    }
}


function chopCurrentTime() {
      if(ytplayer2 && id) {
            var start;
            var end;
            if (ytplayer2.getCurrentTime() <= 5) {
                start = 0;
            }
            else {
                start = ytplayer2.getCurrentTime() - 5;
            }

            if (ytplayer2.getDuration() - ytplayer2.getCurrentTime() <= 5) {
                end = ytplayer2.getDuration();
            }
            else {
                end = ytplayer2.getCurrentTime() + 5;
            }
            

            videoData[liNo] = {videoId: id, 
                               videoStart: start, 
                               videoEnd: end};

            startTime = start;
            endTime = end;

            var l = '<li id=\"li' + liNo + '\"><div class=\"thumbnail\"><p><span id=\"a' + liNo + '\"><a onclick=\"loadVideo2(\'' + id + '\',' + start + ',' + end + ', ' + liNo + ')\" href=\"#\">' + start + '-' + end + '</a></span> | <a href=\"#\" onclick=\"deleteClip(' + liNo + ')\">delete</a></p><div class=\"input-group\"><span class=\"input-group-addon\">Question:</span><input class="form-control" id=\"question' + liNo + '\" type=\"text\" /></div><div class=\"input-group\"><span class=\"input-group-addon\">Answer:</span><input class=\"form-control\" id=\"answer' + liNo + '\" type=\"text\" /></div><div class=\"input-group\"><span class=\"input-group-addon\">Long Answer:</span><input class=\"form-control\" id=\"lanswer' + liNo + '\" type=\"text\" /></div></div></li>';
            $("#chopedlist").append(l);

            liNo++;
            //isOriginal = 1;
      }
}
function deleteClip(liNo) {
    $("#li" + liNo).closest('li').remove();
    delete videoData[liNo];
}


function update() {
    for (var i in videoData) {
        videoData[i]["videoQuestion"] = document.getElementById("question" + i).value;
        videoData[i]["videoAnswer"] = document.getElementById("answer" + i).value;
        videoData[i]["videoLongAnswer"] = document.getElementById("lanswer" + i).value;
    }
    localStorage.clear();
    localStorage["data"] = JSON.stringify(videoData);
}

