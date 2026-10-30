/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "confirmEmailChangeTemplate": {
      "body": "<p>سلام،</p><p>برای تأیید تغییر ایمیل خود روی لینک زیر بزنید:</p><p><a href=\"{APP_URL}/_/#/auth/confirm-email-change/{TOKEN}\">تأیید تغییر ایمیل</a></p><p>اگر شما این درخواست را نداده‌اید، این ایمیل را نادیده بگیرید.</p>",
      "subject": "تغییر ایمیل ZAR+"
    },
    "verificationTemplate": {
      "body": "<p>سلام،</p><p>برای تأیید ایمیل خود روی لینک زیر بزنید:</p><p><a href=\"{APP_URL}/_/#/auth/confirm-verification/{TOKEN}\">تأیید ایمیل</a></p><p>اگر شما این درخواست را نداده‌اید، این ایمیل را نادیده بگیرید.</p>",
      "subject": "تأیید ایمیل ZAR+"
    }
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "confirmEmailChangeTemplate": {
      "body": "<p>Hello,</p>\n<p>Click on the button below to confirm your new email address.</p>\n<p>\n  <a class=\"btn\" href=\"{APP_URL}/_/#/auth/confirm-email-change/{TOKEN}\" target=\"_blank\" rel=\"noopener\">Confirm new email</a>\n</p>\n<p><i>If you didn't ask to change your email address, please ignore this email.</i></p>\n<p>\n  Thanks,<br/>\n  {APP_NAME} team\n</p>",
      "subject": "Confirm your {APP_NAME} new email address"
    },
    "verificationTemplate": {
      "body": "<p>Hello,</p>\n<p>Thank you for joining us at {APP_NAME}.</p>\n<p>Click on the button below to verify your email address.</p>\n<p>\n  <a class=\"btn\" href=\"{APP_URL}/_/#/auth/confirm-verification/{TOKEN}\" target=\"_blank\" rel=\"noopener\">Verify</a>\n</p>\n<p><i>If you didn't recently register, please ignore this email.</i></p>\n<p>\n  Thanks,<br/>\n  {APP_NAME} team\n</p>",
      "subject": "Verify your {APP_NAME} email"
    }
  }, collection)

  return app.save(collection)
})
