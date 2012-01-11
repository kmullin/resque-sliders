$(document).ready(function() {
  function set_total() {
    var total = 0;
    $(".values").each(function () {
      total += parseInt($(this).val());
    });
    $("#total").text(total);
  };
  function sanitize_input(s) {
    var ary = s.toLowerCase().replace(/[^a-z 0-9,_\-\*]/g, '').replace(/^\s+|\s+$/g, '').split(',');
    var new_ary = [];
    $.each(ary, function() {
      if (this != '') {
        new_ary.push($.trim(this));
      }
    });
    return new_ary.join(',');
  };
  // Click function for all icons
  $(".ui-icon").click(function() {
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
    $.post('/sliders/' + host, signal, function(data) {
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
  $('.new_form').submit(function() {
    var queue = sanitize_input($("#new_queue").val());
    var host = $(this).attr("id");
    $.post('/sliders/' + host, { quantity: 1, queue: queue }, function(data) {
      // do something here on success
    });
  });
  $("#plus-one").click(function() {
    $('.new_form').submit();
  });
  // make each slider, get input from div content passed from erb
  $(".slider").each(function() {
    var slidy = $(this);
    var max_childs = parseInt($("#max").text());
    if (max_childs) { max_childs = max_childs; }
    else { max_childs = 50; }
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
        $.post('/sliders/' + host, { quantity: ui.value, queue: queue }, function(data) {
        });
      },
    });
  });
  set_total(); // do this initially
});
