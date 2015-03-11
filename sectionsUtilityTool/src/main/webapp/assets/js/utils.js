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
  switch(status) {
    case 403:
      window.location = '/sectionsUtilityTool/error.html';
      break;
    default:
      $('#debugPanel').html('<h3>' + status + '</h3><p><code>' + url + '</code></p><p>' + errorMessage + '</p>');
      $('#debugPanel').fadeIn().delay(5000).fadeOut();
  }
};

var getCurrentTerm = function(termData) {
  var now = moment();
  var currentTerm = [];
  $.each(termData, function() {
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
  $('#successContainer').css('top', position);
  $('#successContainer').find('.msg').html(msg);
  $('#successContainer').fadeIn().delay(3000).fadeOut();
};

var reportError = function(position, msg){
  $('#errorContainer').css('top', position);
  $('#errorContainer').find('.msg').html(msg);
  $('#errorContainer').fadeIn();
};

/**
 * Pop a window to display help matters, name allows to pass the 
 * focus to it if already open and in the background
 * 
 * @param {Object} url 
 * @param {Object} name - window name
 */
var utilPopWindow = function(url, name){
    var notAModal = window.open(url, name, 'height=800,width=600, toolbar=yes, menubar=yes, scrollbars=yes, resizable=yes');
    if (window.focus) {
        notAModal.focus();
    }
    return false;
};

/**
 *
 * event watchers
 */

//open help doc in new window
$('#helpLink').click(function(){
    utilPopWindow('help.html', 'help');
});

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
    $('#listOfSectionsToCrossList').append( '<li id=\"xListSection' + $(this).attr('data-sectionid') + '\">' + $(this).find('div.sectionName span').text() + '</li>');
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
  .fail(function(jqXHR) {
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
  .fail(function(jqXHR) {
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
  var position = $(e.target).closest('.course').position().top;
  $.ajax({
    type: 'PUT',
    url: url
    }).done(function( msg ) {
     $('.courseTitleTextContainer').hide();
      reportSuccess(position, 'Course <strong>' + $thisCourseCode.text() + '</strong> renamed to <strong>' + msg.course_code + '</strong>');
      $thisCourseCode.text(msg.course_code);
      $thisCourseName.text(msg.name);
    }).fail(function(jqXHR) {
      reportError(position,'There was an error changing this course name' + ' (' + jqXHR.status + ' ' + jqXHR.statusText + ')');
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

$(document).on('click', '#uniqnameOtherTrigger', function (e) {
  e.preventDefault();
  var uniqnameOther = $.trim($('#uniqnameOther').val());
  var termId = $.trim($('#canvasTermId').text());
  var mini='/manager/api/v1/courses?as_user_id=sis_login_id:' +uniqnameOther+ '&include=sections&per_page=100&published=true&with_enrollments=true&enrollment_type=teacher';
  var url = '/sectionsUtilityTool'+mini;
  
  $.ajax({
    type: 'GET',
    url: url
    }).done(function( data ) {
      if(data.errors) {
        $('<span class="alert alert-danger" style="display:none" id="uniqnameOtherError">' + data.errors + '</span>').insertAfter('#uniqnameOtherTrigger');
        $('#uniqnameOtherError').fadeIn().delay(3000).fadeOut();
      }
      else {
        var termIdInt = parseInt(termId);
        var filteredData = _.where(data, {enrollment_term_id:termIdInt});
        var render = '<div class="coursePanelOther well"><ul class="container-fluid courseList">';
        $.each(filteredData, function() {
          var course_code = this.course_code;
          render = render + '<li class="course"><p><strong>' + this.course_code + '</strong></p><ul class="sectionList">';
          $.each(this.sections, function() {
              render = render + '<li class="section row otherSection" data-sectionid="' + this.id + '">' +
                '<div class="col-md-5 sectionName"><input type="checkbox" class="otherSectionSelection courseOtherPanelChild" id="otherSectionSelection' + course_code + this.id + '">' +
                ' <label for="otherSectionSelection' +  course_code + this.id + '" class="courseOtherPanelChild">' + this.name + '</label>' + 
                '<span class="coursePanelChild">' + this.name +'</span></div><div class="col-md-7">'+ 
                '<span class="coursePanelChild"> Originally from ' + course_code + ' (' + uniqnameOther +')</span>' + 
                ' <a href="" class="coursePanelChild removeSection">Remove?</a></div></li>';
          });
          render = render + '</ul></li>';
        });
        render = render + '</ul></div>';
        $('#otherInstructorInnerPayload').append(render);
      }
    }).fail(function() {
      alert('Could not get courses for ' + uniqnameOther);
  });
});

$(document).on('click', '#useOtherSections', function () {
  $('#otherInstructorModal').find('.otherSectionSelection:checked').closest('li').appendTo('.otherSectionsTarget ul.sectionList');
  $('.otherSectionsTarget').find('.setSections').show();
  $('#otherInstructorModal').modal('hide');
});

$(document).on('click', '.openOtherInstructorModal', function (e) { 
  $('#otherInstructorInnerPayload').empty();
  $('#uniqnameOther').val('');
  $('#uniqnameOtherTrigger').text('Look up courses');
  $('#otherInstructorModal').on('shown.bs.modal', function (event) {
      $('li.course').removeClass('otherSectionsTarget');
      $(event.relatedTarget.originalEvent.explicitOriginalTarget).closest('li').addClass('otherSectionsTarget');
    }).on('hidden.bs.modal', function () {
        $('li.course').removeClass('otherSectionsTarget');
    }).modal('toggle', e);
});

$(document).on('click', '.removeSection', function (e) {
  e.preventDefault();
  $(this).closest('li').fadeOut( 'slow', function() {
    $(this).remove();
  });

});
