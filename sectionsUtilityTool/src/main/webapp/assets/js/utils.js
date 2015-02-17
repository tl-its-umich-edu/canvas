'use strict';
/* jshint  strict: true*/
/* global $, moment, _*/



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
        currentTerm.currentTermCanvasId =  this.id;
      }
    }
  });
  return currentTerm;  
};

var getTermArray = function(coursesData) {
  var termArray = [];
  $.each(coursesData, function() {
    if(this.enrollment_term_id !== null && this.enrollment_term_id !== undefined){
      termArray.push(this.enrollment_term_id);
      $('li[ng-data-id=' + this.enrollment_term_id + ']').show();
    }
  });
  termArray = _.uniq(termArray);
  return termArray;  
};
/**
 *
 * event watchers
 */

//handler for the Update Course button
$(document).on('click', '.setSections', function (e) {
  e.preventDefault();
  var thisCourse = $(this).attr('data-courseid');
  var thisCourseTitle = $(this).closest('li').find('.courseLink').text();
  var $sections = $(this).closest('li').find('ul').find('li');
  var posts = [];
  $('#xListInner').empty();
  $('#xListInner').append('<p><strong>' + thisCourseTitle + '</strong></p><ol id="listOfSectionsToCrossList"></ol>');
  $sections.each(function( ) {
    posts.push('/api/v1/sections/' + $(this).attr('data-sectionid') + '/crosslist/' + thisCourse)
    $('#listOfSectionsToCrossList').append( '<li>' + $(this).find('.sectionName').text() + '</li>');
  });
  $('#xListInner').append(posts.join('<br>'))
  return null;
});

$('body').on('keydown','#uniqname', function(event) {
  if (event.keyCode == 13) {
    $('#uniqnameTrigger').click();
  }
});
