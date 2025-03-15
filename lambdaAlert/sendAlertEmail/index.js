const aws = require('aws-sdk')

const oParams = {
    Destination: { /* required */
        ToAddresses: [
            "tschui+ce8@gmail.com",
            /* more items */
        ]
    },
    Message: { /* required */
        Body: { /* required */
            Text: {
                Charset: "UTF-8",
                Data: ""
            }
        },
        Subject: {
            Charset: "UTF-8",
            Data: "KPI Alert"
        }
    },
    Source: "tschui@gmail.com", /* required */
}

const ses = new aws.SES()

exports.handler = async (event) => {
    console.log(JSON.stringify(event))

    for (let item of event.Records) {

        if (item.eventName === 'REMOVE') return

        /**********************Parsing the params from event object*******************/
        const plant = item.dynamodb.NewImage.Plant['S']
        const line = item.dynamodb.NewImage.Line['S']
        const actualValue = parseInt(item.dynamodb.NewImage.KpiValue['N'])
        const thresholdValue = parseInt(item.dynamodb.NewImage.ThresholdValue['N'])
        const kpiName = item.dynamodb.NewImage.KpiName['S']
        /*****************************************************************************/

        if (actualValue > thresholdValue) {
            try {
                const msgBody = `${kpiName} has exceeded the threshold value ${thresholdValue} by ${actualValue - thresholdValue} units for plant ${plant} and line ${line}`

                oParams.Message.Body.Text['Data'] = msgBody
                await ses.sendEmail(oParams).promise()
            } catch (error) {
                return error.message
            }
        }
    }
}
