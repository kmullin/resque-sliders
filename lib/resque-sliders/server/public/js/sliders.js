$(document).ready(function() {
  function set_total() {
    var total = 0;
    $(".values").each(function () {
      total += parseInt($(this).val());
    });
    $("#total").text(total);
  };
  function sanitize_input(s) {
    // delete non-friendly chars, replace spaces in words with commas for resque
    var ary = s.replace(/['":]/g, '').replace(/^\s+|\s+$/g, '').replace(/\s+/g, ',').split(/, */);
    var new_ary = [];
    // remove empties from array
    $.each(ary, function() {
      if (this != '') {
        new_ary.push($.trim(this));
      }
    });
    return new_ary.join(',');
  };
  // Click function for all icons
  $(".controls").find("span").click(function() {
    var host_sig = $(this).attr("id").split(':');
    var host = host_sig[0];
    switch(host_sig[1])
    {
      case 'REFRESH':
        sig = 'reload';
        break;
      case 'ALERT':
        return false;
      default:
        sig = host_sig[1].toLowerCase();
    }
    var signal = {};
    signal[sig] = true;

    var span = $(this);
    var re = new RegExp('/' + host + '$');
    var url = window.location.pathname.replace(re, '') + '/' + host;
    $.post(url, signal, function(data) {
      switch(data.signal) {
        case 'reload':
          span.removeClass('ui-icon-refresh').addClass('ui-icon-alert').attr('id', [host, 'ALERT'].join(':'));
          break;
        case 'pause':
          span.removeClass('ui-icon-pause').addClass('ui-icon-play').attr('id', [host, 'PLAY'].join(':'));
          break;
        case 'play':
          span.removeClass('ui-icon-play').addClass('ui-icon-pause').attr('id', [host, 'PAUSE'].join(':'));
          break;
        case 'stop':
          $('#'+host+'\\:PAUSE').removeClass('ui-icon-pause').addClass('ui-icon-play').attr('id', [host, 'PLAY'].join(':'));
          break;
      }
    }, "json");
  });
  $('.new_form').submit(function(e) {
    e.preventDefault();
    var queue = sanitize_input($("#new_queue").val());
    var host = $(this).attr("id");
    if (queue != '') {
      $.post(host, { quantity: 1, queue: queue }, function(data) {
        // reload window
        window.location.reload(true);
      });
    }
  });
  $("#plus-one").click(function() {
    $('.new_form').submit();
  });
  // make each slider, get input from div content passed from erb
  $(".slider").each(function() {
    var slidy = $(this);
    var max_childs = parseInt($("#max").text());
    if (max_childs) { max_childs = max_childs; }
    else { max_childs = 1000; }
    var value = parseInt( slidy.text() );
    var queue = slidy.attr("id").replace("-slider", "").replace(/:/g, ",").replace(/^\s+|\s+$/g, '');
    var host = window.location.pathname.split('/').slice(-1);
    slidy.prev().find("input").val( value );
    slidy.empty().slider({
      range: "min",
      value: value,
      min: 0,
      max: max_childs,
      slide: function( event, ui ) {
        slidy.prev().find("input").val( ui.value );
        set_total();
      },
      change: function( event, ui ) {
        $.post('', { quantity: ui.value, queue: queue }, function(data) {
        });
      },
    });
  });
  set_total(); // do this initially
});
