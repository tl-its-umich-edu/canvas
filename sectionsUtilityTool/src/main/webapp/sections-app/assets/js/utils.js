'use strict';
/* jshint  strict: true*/
/* global $*/



/**
 * set up global ajax options
 */
$.ajaxSetup({
  type: 'GET',
  dataType: 'json',
  cache: false
});

/**
 *
 * event watchers
 */

//handler for the Update Course button
$(document).on('click', '.setSections', function (e) {
  e.preventDefault();
  $('#debugPanel').empty();
  var thisCourse = $(this).attr('data-courseid');
  var $sections = $(this).closest('li').find('ul').find('li');
  $sections.each(function( ) {
    //TODO: this needs to be the servlet endpoint
    // right now just showing it in the UI

    $('#debugPanel').append( '<p>POST /api/v1/sections/<strong>' + $(this).attr('data-sectionid') + '</strong>/crosslist/<strong>' + thisCourse + '</strong></p>');
  });
  $('#debugPanel').fadeIn('fast').delay(3000).fadeOut('slow');
  return null;
});

$(document).ready(function(){
  $('#uniqname').focus();
});
