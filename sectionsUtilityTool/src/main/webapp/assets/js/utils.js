'use strict';
/* jshint  strict: true*/
/* global $, moment*/



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

var getCurrentTerm = function(termData) {
  var now = moment();
  var currentTerm = [];
  $.each(termData, function() {
    //horrifying
    //TODO: deal with Med School terms later - as this is filtering anyth8ing that does not end in '0'
    if(moment(this.start_at).isBefore(now) && moment(this.end_at).isAfter(now)) {
      if (this.sis_term_id !== null && this.sis_term_id !== undefined  && this.sis_term_id.slice(-1) ==='0'){
        currentTerm.currentTermId =  this.sis_term_id;
        currentTerm.currentTermName =  this.name;
      }
    }
  });
  return currentTerm;  
};



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

$('body').on('keydown','#uniqname', function(event) {
  if (event.keyCode == 13) {
    $('#uniqnameTrigger').click();
  }
});