'use strict';
/* global $, _, angular */

var sectionsApp = angular.module('sectionsApp', ['sectionsFilters']);

sectionsApp.run(function ($rootScope) {
  $rootScope.user = $.trim($('#uniqname').val());
});


/* TERMS CONTROLLER */
sectionsApp.controller('termsController', ['Courses', '$rootScope', '$scope', '$http', function (Courses, $rootScope, $scope, $http) {
  //void the currently selected term
  $scope.selectedTerm = null;
  //reset term scope
  $scope.terms = [];
  //term url - below from sample data
  //TODO: needs changing to the servlet endpoint
  var termsUrl = '/sectionsUtilityTool/section_data/terms.json';
  //var termsUrl = 'terms';

  $http.get(termsUrl).success(function (data) {
    $scope.terms = data.enrollment_terms;
  });

  //user selects a term from the dropdown that has been 
  //populated by $scope.terms 
  $scope.getTerm = function (termId, termName) {
    $scope.$parent.termName = termName;
    $scope.$parent.loading = true;
    /*reset $scope.$parent.courses
    commented out here */
    //$scope.$parent.courses = [];

    var uniqname = $.trim($('#uniqname').val());
    //TODO: needs changing to the servlet endpoint
    var url = '/api/v1/courses?as_user_id=sis_login_id:' + uniqname + '&per_page=100&enrollment_term_id=sis_term_id:' +  termId + '&published=true&with_enrollments=true&enrollment_type=teacher&access_token=<acccess-token>';

    //put request in UI as a placeholder - remove when feed works
    $('#debugPanel').empty();
    $('#debugPanel').append( '<p>GET ' + url + '</p>');
    $('#debugPanel').fadeIn('fast').delay(3000).fadeOut('slow');


    //TODO: uncomment  below when servlet has an endpoint
    /*
    Courses.getCourses(url).then(function (data) {
      if (data.failure) {
        $scope.$parent.courses.errors = data;
        $scope.$parent.loading = false;
      } else {
          $scope.$parent.courses = data;
          $scope.$parent.loading = false;
      }
    });
    */
  };

}]);

//COURSES CONTROLLER
sectionsApp.controller('coursesController', ['Courses', 'Sections', '$rootScope', '$scope', function (Courses, Sections, $rootScope, $scope) {
  $scope.courses = [];
  $scope.loading = true;

 $scope.getCoursesForUniqname = function () {
    var uniqname = $.trim($('#uniqname').val());
    $scope.uniqname = uniqname;

    //TODO: needs to be a servlet URL
    var mini="/manager/api/v1/courses?as_user_id=sis_login_id:"+uniqname+"&per_page=100&enrollment_term_id=sis_term_id:2020published=true&with_enrollments=true&enrollment_type=teacher";
    //var mini="/manager/api/v1/courses/656/sections?per_page=100";
    //var mini="/manager/api/v1/accounts/1/terms";
    var url = '/sectionsUtilityTool'+mini;
   // var url = '../../section_data/courses-' + uniqname + '.json';
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
  /*User clicks on Get Sections and the sections for that course
  gets added to the course scope*/
  $scope.getSections = function (courseId, uniqname) {
    Sections.getSectionsForCourseId(courseId, uniqname).then(function (data) {
      if (data) {
        //find the course object
        var coursePos = $scope.courses.indexOf(_.findWhere($scope.courses, {id: courseId}));
        //append a section object to the course scope
        $scope.courses[coursePos].sections = data.data;
        //sectionsShown = true hides the Get Sections link
        $scope.courses[coursePos].sectionsShown = true;
        
        //setting up the jQuery sortable
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
      } else {
        //deal with this
      }
    });
};
}]);


