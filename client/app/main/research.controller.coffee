'use strict'

angular.module('cocApp')
.controller 'ResearchCtrl', ($scope, $modal, $interval, util, lodash, ngToast, userFactory, data) ->
    # user = userFactory.get()

    user = data.user
    $scope.viewname = data.viewname

    $scope.costStr = util.costStr
    $scope.timeStr = util.timeStr
    $scope.costFormat = util.costFormat
    $scope.upgradeList = user.upgrade
    $scope.limitTo = user.limitTo
    $scope.remainTime = util.remainTime
    $scope.timeStrMoment = util.timeStrMoment

    intervalPromise = $interval ()->
        return if $scope.viewname
        if !util.checkUpgrade(user)
            update()
    , 5000
    $scope.$on '$destroy', () ->
        $interval.cancel(intervalPromise)

    labLevel = util.max_level(user.hall, bD['laboratory']['required town hall'])

    nextUpgrade = (current, maxLevel, timeArray, costArray, type) ->
        return {} if (current >= maxLevel)
        switch type
            when 'Dark' then type = 'd'
            else type = 'e'
        data = []
        for i in [current..maxLevel-1]
            data.push([i+1, costArray[i], timeArray[i]*60])
        return {
        type: type
        data: data
        }

    update = () ->
        $scope.data = []
        for title in util.upgrade_list()
            name = util.cannonicalName(title)
            user[name] ?= 0
            maxlevel = util.max_level(labLevel, rD[name]['laboratory level'])
            continue if (typeof rD[name].subtype != 'undefined' || maxlevel <= 1)
            continue if (user.set.hideDoneResearch && user[name] >= maxlevel)
            find = lodash.findIndex(user.upgrade, {
                name: name,
                index: -1
            })
            level = user[name]
            level++ if find >= 0
            $scope.data.push
                title: title
                name: name
                level: user[name]
                maxLevel: maxlevel
                nextUpgrade: nextUpgrade(level, maxlevel,
                    rD[name]['research time'], rD[name]['research cost'],
                    rD[name]['barracks type'])
                upgradeIdx: find
        $scope.summary = util.totalResearchCostTime(user)

    update()

    $scope.changeLevel = (name, index, inc, maxLevel) ->
        currentLevel = oldLevel = $scope.data[index].level
        currentLevel += inc
        currentLevel = 0 if currentLevel < 0
        currentLevel = maxLevel if currentLevel > maxLevel
        # console.log(name)
        # console.log(rD[name]['research time'] )
        $scope.data[index].level = currentLevel
        $scope.data[index].nextUpgrade = nextUpgrade(currentLevel, maxLevel,
            rD[name]['research time'], rD[name]['research cost'],
            rD[name]['barracks type'])
        if oldLevel != currentLevel
            user[name] = currentLevel
            $scope.summary = util.totalResearchCostTime(user)
            userFactory.set([{key:name, value:user[name]}], user)

    $scope.upgrade = (name, title, index) ->
        level = user[name] ? 0
        user.upgrade ?= []

        find = lodash.findIndex(user.upgrade, {
            name: name,
            index: -1
        })
        if (find < 0)
            upgradeNum = lodash.filter user.upgrade, (u) ->
                return u.index < 0
            if (upgradeNum.length >= 1)
                ngToast.create(
                    className: 'warning'
                    content: 'research in progress...')
                return

        ut = rD[name]['research time']
        if (find >= 0)
            due = moment(user.upgrade[find].due)
            value = parseInt(moment.duration(due.diff(moment())).asMinutes())
        else
            value = ut[level]*60

        modalInstance = $modal.open
            templateUrl: 'myModalContent.html'
            controller: 'ModalInstanceCtrl',
            resolve:
                data: () ->
                    {
                    sliderValue: value
                    title: title
                    sliderMax: ut[level]*60
                    level: level+1
                    update: (find >= 0)
                    }
        modalInstance.result.then (value) ->
            $scope.upgradeAction(name, title, index, value)

    $scope.upgradeAction = (name, title, index, value) ->
        level = user[name] ? 0
        user.upgrade ?= []

        find = lodash.findIndex(user.upgrade, {
            name: name,
            index: -1
        })
        ut = rD[name]['research time']
        if (value < 0)
            lodash.remove(user.upgrade, {
                name: name
                index: -1
            })
            $scope.data[index].upgradeIdx = -1
            # console.log($scope.data[index])
        else
            due = new moment()
            due = due.add(value, 'minutes')
            if (find < 0)
                user.upgrade.push(
                    name: name
                    title: title
                    index: -1
                    level: level+1
                    time: ut[level]*60
                    due: due
                )
                $scope.data[index].upgradeIdx = user.upgrade.length-1
            else
                user.upgrade[find] =
                    name: name
                    title: title
                    index: -1
                    level: level+1
                    time: ut[level]*60
                    due: due
                $scope.data[index].upgradeIdx = find
            level++
        maxlevel = util.max_level(labLevel, rD[name]['laboratory level'])
        $scope.data[index].nextUpgrade = nextUpgrade(level, maxlevel,
            rD[name]['research time'], rD[name]['research cost'],
            rD[name]['barracks type'])
        $scope.summary = util.totalResearchCostTime(user)
        userFactory.set([{key:'upgrade', value:user.upgrade}], user)

    $scope.popover = (name, level) ->
        ret = ''
        if (rD[name]['dps'])
            ret += 'dps:'
            ret += rD[name]['dps'][level-1]
            ret += '('+parseInt((rD[name]['dps'][level-1]-rD[name]['dps'][level-2])*100/rD[name]['dps'][level-2])+'%)' if level>1
            ret += '    '
        if (rD[name]['hps'])
            ret += 'hps:'
            ret += rD[name]['hps'][level-1]
            ret += '('+parseInt((rD[name]['hps'][level-1]-rD[name]['hps'][level-2])*100/rD[name]['hps'][level-2])+'%)' if level>1
            ret += '    '
        if (rD[name]['hitpoints'])
            ret += 'hp:'
            ret += rD[name]['hitpoints'][level-1]
            ret += '('+parseInt((rD[name]['hitpoints'][level-1]-rD[name]['hitpoints'][level-2])*100/rD[name]['hitpoints'][level-2])+'%)' if level>1
            ret += '    '
