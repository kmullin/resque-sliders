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
  // Click function for all HUP icons
  $(".HUP").click(function() {
    var host = $(this).attr("id").replace('-HUP', '');
    $.post('/sliders/' + host, { reload: true }, function(data) {
      // FIXME
      // this should just show the alert icon
      window.location.reload();
    });
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
