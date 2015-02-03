'use strict';
/* jshint  strict: true*/
/* global $, alert*/



/**
 * set up global ajax options
 */
$.ajaxSetup({
  type: 'GET',
  dataType: 'json',
  cache: false
});

var errorHandler = function (url, result) {
  var errorResponse = {};
  if (!result) {
    errorResponse.message = 'Something happened!';
    errorResponse.requestUrl = url;
    errorResponse.details = result.status;

  } else {
    errorResponse.message = 'Something happened with a service we depend on!';
    errorResponse.requestUrl = url;
    errorResponse.details = result.status;
  }
  return errorResponse;

};

/**
 *
 * event watchers
 */

$(document).on('click', '.setSections', function (e) {
  e.preventDefault();
  $('#debugPanel').empty();
  var thisCourse = $(this).attr("data-courseid");
  var thisCourseSections = [];
  var $sections = $(this).closest('li').find('ul').find('li');
  $sections.each(function( ) {
    $('#debugPanel').append( '<p>POST /api/v1/sections/<strong>' + $(this).attr("data-sectionid") + '</strong>/crosslist/<strong>' + thisCourse + '</strong></p>');
  });
  $('#debugPanel').fadeIn('fast').delay(3000).fadeOut('slow');
  return null;
});
