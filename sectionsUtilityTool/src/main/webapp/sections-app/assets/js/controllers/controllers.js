'use strict';
/* jshint  strict: true*/
/* global $, _, angular, console */

var sectionsApp = angular.module('sectionsApp', ['sectionsFilters']);

sectionsApp.run(function ($rootScope) {
  $rootScope.user = $.trim($('#uniqname').val());
});



sectionsApp.controller('termsController', ['Courses', '$rootScope', '$scope', '$http', function (Courses, $rootScope, $scope, $http) {
  $scope.selectedTerm = null;
  //$scope.terms = [];
  var termsUrl = '../../../section_data/terms.json';
  //var termsUrl = 'terms';

  $http.get(termsUrl).success(function (data) {
    $scope.terms = data.enrollment_terms;
  });

  $scope.getTerm = function (termId, termName) {
    $scope.$parent.loading = true;
    //$scope.$parent.courses = [];
    
    //var url = 'courses/' + $rootScope.user + '.json'+ '?TERMID='+termId;
    var uniqname = $.trim($('#uniqname').val());
    var url = '/api/v1/courses?as_user_id=sis_login_id:' + uniqname + '&per_page=100&enrollment_term_id=sis_term_id:' +  termId + '&published=true&with_enrollments=true&enrollment_type=teacher&access_token=<acccess-token>';
    //console.log('GET ' + url)
    $('#debugPanel').empty();
    $('#debugPanel').append( '<p>GET ' + url + '</p>');
    $('#debugPanel').fadeIn('fast').delay(3000).fadeOut('slow');

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


sectionsApp.controller('coursesController', ['Courses', 'Sections', '$rootScope', '$scope', function (Courses, Sections, $rootScope, $scope) {
  $scope.courses = [];
  $scope.loading = true;

 $scope.getCoursesForUniqname = function () {
    var uniqname = $.trim($('#uniqname').val());
    $scope.uniqname = uniqname;
    var url = '../../../section_data/courses-' + uniqname + '.json';
    Courses.getCourses(url).then(function (data) {
      if (data.failure) {
        if(uniqname) {
          $scope.errorMessage = 'Could not get data for uniqname \"' + uniqname + '\"';
        }
        else {
          $scope.errorMessage = 'Please supply a uniqname at left';
        }
        $scope.success = false;
        $scope.error = true;
      } else {
        $scope.courses = data.data;
        $scope.error = false;
        $scope.success = true;
        $scope.successMessage = 'Found ' + data.data.length + ' courses for ';
        $scope.instructions = true;
      }
    });
  };
  $scope.getSections = function (courseId, uniqname) {
    Sections.getSectionsForCourseId(courseId, uniqname).then(function (data) {
      if (data) {
        var coursePos = $scope.courses.indexOf(_.findWhere($scope.courses, {id: courseId}));
        $scope.courses[coursePos].sections = data.data;
        $('.sectionList').sortable({
          connectWith: '.sectionList',
          stop: function( event, ui ) {
            //ui.item.fadeOut('fast').delay(3000).fadeIn('slow');
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


