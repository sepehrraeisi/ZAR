/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "resetPasswordTemplate": {
      "body": "<p>سلام،</p><p>برای بازنشانی رمز عبور روی لینک زیر بزنید:</p><p><a href=\"{APP_URL}/_/#/auth/confirm-password-reset/{TOKEN}\">بازیابی رمز عبور</a></p><p>اگر شما این درخواست را نداده‌اید، این ایمیل را نادیده بگیرید.</p>",
      "subject": "بازیابی رمز عبور ZAR+"
    }
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "resetPasswordTemplate": {
      "body": "<p>Hello,</p>\n<p>Click on the button below to reset your password.</p>\n<p>\n  <a class=\"btn\" href=\"{APP_URL}/_/#/auth/confirm-password-reset/{TOKEN}\" target=\"_blank\" rel=\"noopener\">Reset password</a>\n</p>\n<p><i>If you didn't ask to reset your password, please ignore this email.</i></p>\n<p>\n  Thanks,<br/>\n  {APP_NAME} team\n</p>",
      "subject": "Reset your {APP_NAME} password"
    }
  }, collection)

  return app.save(collection)
})
