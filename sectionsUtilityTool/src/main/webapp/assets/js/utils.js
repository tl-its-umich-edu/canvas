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

var errorDisplay = function (url, status, errorMessage) {
  $('#debugPanel').html('<h3>' + status + '</h3><p><code>' + url + '</code></p><p>' + errorMessage + '</p>');
  $('#debugPanel').fadeIn().delay(5000).fadeOut();
};
     
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

var calculateLastActivity = function(last_activity_at) {
  if(last_activity_at) {
    return moment(last_activity_at).fromNow();
  } 
  else {
    return 'None';
  }
};

var reportSuccess = function(position, msg){
  $('#successContainer').css('top', position - 300);
  $('#successContainer').find('.msg').html(msg);
  $('#successContainer').fadeIn().delay(3000).fadeOut();
};

var reportError = function(position, msg){
  $('#errorContainer').css('top', position - 300);
  $('#errorContainer').find('.msg').html(msg);
  $('#errorContainer').fadeIn().delay(3000).fadeOut();
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

  var thisCourseTitle = $(this).closest('li').find('a.courseLink').text();
  var $sections = $(this).closest('li').find('ul').find('li');
  var posts = [];
  $('#xListInner').empty();
  $('#xListInner').append('<p><strong>' + thisCourseTitle + '</strong></p><ol id="listOfSectionsToCrossList" class="listOfSectionsToCrossList"></ol>');
  $sections.each(function( ) {
    posts.push('/api/v1/sections/' + $(this).attr('data-sectionid') + '/crosslist/' + thisCourse);
    $('#listOfSectionsToCrossList').append( '<li id=\"xListSection' + $(this).attr('data-sectionid') + '\">' + $(this).find('.sectionName').text() + '</li>');
  });
  $('#postXList').click(function(){
    var index, len;
    for (index = 0, len = posts.length; index < len; ++index) {
      var xListUrl ='manager' + posts[index];
      $.post(xListUrl, function(data) {
        var section = data.id;
        $('#xListSection' +  section).append('<span class=\"label label-success\">Success</span>');
      })
      .fail(function(data) {
        var section = data.id;
        $('#xListSection' +  section).append('<span class=\"label label-failure\">Failure</span>');
      })
      .always(function() {
        // need to count the success / failures
      });


    }  
  });
  return null;
});
  
$(document).on('click', '.getCourseInfo', function (e) {
  var uniqname = $.trim($('#uniqname').val());
  e.preventDefault();
  var thisCourse = $(this).attr('data-courseid');
  var thisCourseTitle = $(this).closest('li').find('.courseLink').text();
  $('#courseInfoInner').empty();
  $('#courseInfoLabel').empty();
  $('#courseInfoLabel').text('Info on ' + thisCourseTitle);
  $.get('manager/api/v1/courses/' + thisCourse + '/activity_stream?as_user_id=sis_login_id:' +uniqname, function(data) {
      if(!data.length) {
        $('#courseInfoInner').text('No course activity detected!');
      }
      else {
        $('#courseInfoInner').text('Course activity detected! Number of events: '  + data.length); 
      }
  })
  .fail(function(jqXHR, textStatus, errorThrown) {
    $('#courseInfoInner').text('There was an error getting course information'  + ' (' + jqXHR.status + ' ' + jqXHR.statusText + ')'); 
  });
  return null;
});

$('body').on('keydown','#uniqname', function(event) {
  if (event.keyCode == 13) {
    $('#uniqnameTrigger').click();
  }
});

$(document).on('click', '.getEnrollements', function (e) {
  //var uniqname = $.trim($('#uniqname').val());
  e.preventDefault();
  var thisCourse = $(this).attr('data-courseid');
  var thisCourseTitle = $(this).closest('li').find('.courseLink').text();
  $('#courseGetEnrollmentsLabel').empty();
  $('#courseGetEnrollmentsInner').empty();
  $('#courseGetEnrollmentsLabel').text('Enrollments for ' + thisCourseTitle);
  $.get('manager/api/v1/courses/' + thisCourse +  '/enrollments', function(data) {
      if(!data.length) {
        $('#courseGetEnrollmentsInner').text('No humans detected!');
      }
      else {
        $('#courseGetEnrollmentsInner').append('<p>Humans detected: '  + data.length + '</p><ul class="container-fluid"></ul></div>'); 
          $('#courseGetEnrollmentsInner .container-fluid').append('<li class="row"><small><strong><div class="col-md-4 col-lg-4">Name (and uniqname)</div><div class="col-md-4 col-lg-4">Role / section</div><div class="col-md-4 col-lg-4">Last activity</div></strong></small></li>');
        $.each( data, function() {
          $('#courseGetEnrollmentsInner .container-fluid').append('<li class="row"><small><div class="col-md-4 col-lg-4">'  + this.user.name +  ' (' + this.user.login_id + ')</div><div class="col-md-4 col-lg-4">' + this.type + ' /' + this.course_section_id + '</div><div class="col-md-4 col-lg-4">'+ calculateLastActivity(this.last_activity_at) + '</div></small></li>');
        });
      }
  })
  .fail(function(jqXHR, textStatus, errorThrown) {
    $('#courseGetEnrollmentsInner').text('There was an error getting enrollements' + ' (' + jqXHR.status + ' ' + jqXHR.statusText + ')'); 
  });
  return null;
});


$(document).on('click', '.renameCourse', function (e) {
  $('.courseTitleTextContainer').hide();
  e.preventDefault();
  var thisCourseTitle = $(this).closest('li').find('.courseLink').text();
  $(this).next('.courseTitleTextContainer').find('input.courseTitleText').val(thisCourseTitle).focus();
  $(this).next('.courseTitleTextContainer').fadeIn();
  return null;
});

  
$(document).on('click', '.postCourseNameChange', function (e) {
  e.preventDefault();
  var thisCourse = $(this).attr('data-courseid');
  var newCourseName = $(this).closest('.courseTitleTextContainer').find('input.courseTitleText').val();
  var url = 'manager/api/v1/courses/' + thisCourse + '?course[course_code]=' + newCourseName + '&course[name]=' + newCourseName;
  var $thisCourseCode = $(this).closest('li').find('.courseLink');
  var $thisCourseName = $(this).closest('li').find('.courseName');
  var position = e.pageX;

  $.ajax({
    type: 'PUT',
    url: url
    }).done(function( msg ) {
     $('.courseTitleTextContainer').hide();
      reportSuccess(position, 'Course <strong>' + $thisCourseCode.text() + '</strong> renamed to <strong>' + msg.course_code + '</strong>');
      $thisCourseCode.text(msg.course_code);
      $thisCourseName.text(msg.name);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.log(jqXHR)
      reportError(position,'There was an error changing this course name' + ' (' + jqXHR.status + ' ' + jqXHR.statusText + ')')
  });

});

$(document).on('click', '.cancelCourseNameChange', function (e) {
  e.preventDefault();
  $('.courseTitleTextContainer').hide();
});

$('body').on('keydown','#uniqname', function(event) {
  if (event.keyCode == 13) {
    $('#uniqnameTrigger').click();
  }
});


