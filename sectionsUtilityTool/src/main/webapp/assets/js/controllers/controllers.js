'use strict';
/* global $, _, angular, getCurrentTerm */

var sectionsApp = angular.module('sectionsApp', ['sectionsFilters','ui.sortable']);

sectionsApp.run(function ($rootScope) {
  $rootScope.user = $.trim($('#uniqname').val());
});


/* TERMS CONTROLLER */
sectionsApp.controller('termsController', ['Courses', '$rootScope', '$scope', '$http', function (Courses, $rootScope, $scope, $http) {
  //void the currently selected term
  $scope.selectedTerm = null;
  //reset term scope
  $scope.terms = [];
  var termsUrl ='manager/api/v1/accounts/1/terms';
  $http.get(termsUrl).success(function (data) {
    $scope.terms = data.enrollment_terms;
    $scope.$parent.currentTerm =  getCurrentTerm(data.enrollment_terms);
  });

  //user selects a term from the dropdown that has been 
  //populated by $scope.terms 
  $scope.getTerm = function (termId, termName, termCanvasId) {
    $scope.$parent.currentTerm.currentTermName = termName;
    $scope.$parent.currentTerm.currentTermId = termId;
    $scope.$parent.currentTerm.currentTermCanvasId = termCanvasId;
    $scope.$parent.loading = true;
  };

}]);

//COURSES CONTROLLER
sectionsApp.controller('coursesController', ['Courses', 'Sections', '$rootScope', '$scope', function (Courses, Sections, $rootScope, $scope) {
  //$scope.courses = [];
  $scope.loading = true;

 $scope.getCoursesForUniqname = function () {
    var uniqname = $.trim($('#uniqname').val());
    $scope.uniqname = uniqname;
    var mini='/manager/api/v1/courses?as_user_id=sis_login_id:' +uniqname+ '&include=sections&per_page=100&published=true&with_enrollments=true&enrollment_type=teacher';
    var url = '/sectionsUtilityTool'+mini;
    Courses.getCourses(url).then(function (data) {
      if (data.failure) {
        if(uniqname) {
          $scope.errorMessage = 'Could not get data for uniqname \"' + uniqname + '.\"';
          $scope.errorLookup = true;
        }
        else {
          $scope.errorMessage = 'Please supply a uniqname at left.';
          $scope.instructions = false;
          $scope.errorLookup = false;
        }
        $scope.success = false;
        $scope.error = true;
        $scope.instructions = false;
      }
      else {
        $scope.courses = data.data;
        $scope.error = false;
        $scope.success = true;
        $scope.successMessage = 'Found ' + data.data.length + ' courses for ';
        $scope.instructions = true;
        $scope.errorLookup = false;
      }
    });
  };

  $scope.sortableOptions = {
      placeholder: 'section',
      connectWith: '.sectionList',
      start: function(event, ui) {
        ui.item.css({
          'background-color':'#eee',
        });
      },
      receive: function(event, ui) {
      //on drop, append the name of the source course
        var prevMovEl = ui.item.find('.status');
        if(prevMovEl.text() !==''){
          prevMovEl.next('span').show();
        }
        prevMovEl.text('Moved  from ' + ui.sender.closest('.course').find('.courseLink').text());
      },
      stop: function( event, ui ) {
        //add some animation feedback to the move
        ui.item.css('transform', 'rotate(0deg)');
        $('li.course').removeClass('activeCourse');
        ui.item.closest('li.course').addClass('activeCourse');
        ui.item.css('background-color', '#FFFF9C')
          .animate({ backgroundColor: '#FFFFFF'}, 1500);
      }
  };
  

  /*User clicks on Get Sections and the sections for that course
  gets added to the course scope*/
  $scope.getSections = function () {

    $('.sectionList').sortable({
          connectWith: '.sectionList',
          receive: function(event, ui) {
            //on drop, append the name of the source course
            var prevMovEl = ui.item.find('.status');
            if(prevMovEl.text() !==''){
              prevMovEl.next('span').show();
            }
            prevMovEl.text('Moved  from ' + ui.sender.closest('.course').find('.courseLink').text());
          },
          stop: function( event, ui ) {
            //add some animation feedback to the move
            $('li.course').removeClass('activeCourse');
            ui.item.closest('li.course').addClass('activeCourse');
            ui.item.css('background-color', '#FFFF9C')
              .animate({ backgroundColor: '#FFFFFF'}, 1500);
          }
        }).disableSelection();
    
    /*
    event.preventDefault();
    Sections.getSectionsForCourseId(courseId, uniqname).then(function (data) {
      if (data) {
        //find the course object
        var coursePos = $scope.courses.indexOf(_.findWhere($scope.courses, {id: courseId}));
        //append a section object to the course scope
        $scope.courses[coursePos].sections = data.data;
        //sectionsShown = true hides the Get Sections link
        $scope.courses[coursePos].sectionsShown = true;
        
        //setting up the jQuery sortable
    
      } else {
        //deal with this
      }
    });
  */
  };
}]);


