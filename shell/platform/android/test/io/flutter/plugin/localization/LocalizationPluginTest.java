// Part of the embedding.engine package to allow access to FlutterJNI methods.
package io.flutter.embedding.engine;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.os.Build;
import android.os.LocaleList;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.systemchannels.LocalizationChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.localization.LocalizationPlugin;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.Locale;
import org.json.JSONException;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@Config(manifest = Config.NONE)
@RunWith(RobolectricTestRunner.class)
@TargetApi(24) // LocaleList and scriptCode are API 24+.
public class LocalizationPluginTest {
  // This test should be synced with the version for API 24.
  @Test
  public void computePlatformResolvedLocaleAPI26() {
    // --- Test Setup ---
    setApiVersion(26);
    FlutterJNI flutterJNI = new FlutterJNI();

    Context context = mock(Context.class);
    Resources resources = mock(Resources.class);
    Configuration config = mock(Configuration.class);
    DartExecutor dartExecutor = mock(DartExecutor.class);
    LocaleList localeList =
        new LocaleList(new Locale("es", "MX"), new Locale("zh", "CN"), new Locale("en", "US"));
    when(context.getResources()).thenReturn(resources);
    when(resources.getConfiguration()).thenReturn(config);
    when(config.getLocales()).thenReturn(localeList);

    flutterJNI.setLocalizationPlugin(
        new LocalizationPlugin(context, new LocalizationChannel(dartExecutor)));

    // Empty supportedLocales.
    String[] supportedLocales = new String[] {};
    String[] result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    assertEquals(result.length, 0);

    // Empty preferredLocales.
    supportedLocales =
        new String[] {
          "fr", "FR", "",
          "zh", "", "",
          "en", "CA", ""
        };
    localeList = new LocaleList();
    when(config.getLocales()).thenReturn(localeList);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    // The first locale is default.
    assertEquals(result.length, 3);
    assertEquals(result[0], "fr");
    assertEquals(result[1], "FR");
    assertEquals(result[2], "");

    // Example from https://developer.android.com/guide/topics/resources/multilingual-support#postN
    supportedLocales =
        new String[] {
          "en", "", "",
          "de", "DE", "",
          "es", "ES", "",
          "fr", "FR", "",
          "it", "IT", ""
        };
    localeList = new LocaleList(new Locale("fr", "CH"));
    when(config.getLocales()).thenReturn(localeList);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    // The call will use the new (> API 24) algorithm.
    assertEquals(result.length, 3);
    assertEquals(result[0], "fr");
    assertEquals(result[1], "FR");
    assertEquals(result[2], "");

    supportedLocales =
        new String[] {
          "en", "", "",
          "de", "DE", "",
          "es", "ES", "",
          "fr", "FR", "",
          "fr", "", "",
          "it", "IT", ""
        };
    localeList = new LocaleList(new Locale("fr", "CH"));
    when(config.getLocales()).thenReturn(localeList);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    // The call will use the new (> API 24) algorithm.
    assertEquals(result.length, 3);
    assertEquals(result[0], "fr");
    assertEquals(result[1], "");
    assertEquals(result[2], "");

    // Example from https://developer.android.com/guide/topics/resources/multilingual-support#postN
    supportedLocales =
        new String[] {
          "en", "", "",
          "de", "DE", "",
          "es", "ES", "",
          "it", "IT", ""
        };
    localeList = new LocaleList(new Locale("fr", "CH"), new Locale("it", "CH"));
    when(config.getLocales()).thenReturn(localeList);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    // The call will use the new (> API 24) algorithm.
    assertEquals(result.length, 3);
    assertEquals(result[0], "it");
    assertEquals(result[1], "IT");
    assertEquals(result[2], "");

    supportedLocales =
        new String[] {
          "zh", "CN", "Hans",
          "zh", "HK", "Hant",
        };
    localeList = new LocaleList(new Locale("zh", "CN"));
    when(config.getLocales()).thenReturn(localeList);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    assertEquals(result.length, 3);
    assertEquals(result[0], "zh");
    assertEquals(result[1], "CN");
    assertEquals(result[2], "Hans");
  }

  // This test should be synced with the version for API 26.
  @Test
  public void computePlatformResolvedLocaleAPI24() {
    // --- Test Setup ---
    setApiVersion(24);
    FlutterJNI flutterJNI = new FlutterJNI();

    Context context = mock(Context.class);
    Resources resources = mock(Resources.class);
    Configuration config = mock(Configuration.class);
    DartExecutor dartExecutor = mock(DartExecutor.class);
    LocaleList localeList =
        new LocaleList(new Locale("es", "MX"), new Locale("zh", "CN"), new Locale("en", "US"));
    when(context.getResources()).thenReturn(resources);
    when(resources.getConfiguration()).thenReturn(config);
    when(config.getLocales()).thenReturn(localeList);

    flutterJNI.setLocalizationPlugin(
        new LocalizationPlugin(context, new LocalizationChannel(dartExecutor)));

    // Empty supportedLocales.
    String[] supportedLocales = new String[] {};
    String[] result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    assertEquals(result.length, 0);

    // Empty preferredLocales.
    supportedLocales =
        new String[] {
          "fr", "FR", "",
          "zh", "", "",
          "en", "CA", ""
        };
    localeList = new LocaleList();
    when(config.getLocales()).thenReturn(localeList);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    // The first locale is default.
    assertEquals(result.length, 3);
    assertEquals(result[0], "fr");
    assertEquals(result[1], "FR");
    assertEquals(result[2], "");

    // Example from https://developer.android.com/guide/topics/resources/multilingual-support#postN
    supportedLocales =
        new String[] {
          "en", "", "",
          "de", "DE", "",
          "es", "ES", "",
          "fr", "FR", "",
          "it", "IT", ""
        };
    localeList = new LocaleList(new Locale("fr", "CH"));
    when(config.getLocales()).thenReturn(localeList);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    // The call will use the new (> API 24) algorithm.
    assertEquals(result.length, 3);
    assertEquals(result[0], "fr");
    assertEquals(result[1], "FR");
    assertEquals(result[2], "");

    supportedLocales =
        new String[] {
          "en", "", "",
          "de", "DE", "",
          "es", "ES", "",
          "fr", "FR", "",
          "fr", "", "",
          "it", "IT", ""
        };
    localeList = new LocaleList(new Locale("fr", "CH"));
    when(config.getLocales()).thenReturn(localeList);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    // The call will use the new (> API 24) algorithm.
    assertEquals(result.length, 3);
    assertEquals(result[0], "fr");
    assertEquals(result[1], "");
    assertEquals(result[2], "");

    // Example from https://developer.android.com/guide/topics/resources/multilingual-support#postN
    supportedLocales =
        new String[] {
          "en", "", "",
          "de", "DE", "",
          "es", "ES", "",
          "it", "IT", ""
        };
    localeList = new LocaleList(new Locale("fr", "CH"), new Locale("it", "CH"));
    when(config.getLocales()).thenReturn(localeList);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    // The call will use the new (> API 24) algorithm.
    assertEquals(result.length, 3);
    assertEquals(result[0], "it");
    assertEquals(result[1], "IT");
    assertEquals(result[2], "");
  }

  // Tests the legacy pre API 24 algorithm.
  @Test
  public void computePlatformResolvedLocaleAPI16() {
    // --- Test Setup ---
    setApiVersion(16);
    FlutterJNI flutterJNI = new FlutterJNI();

    Context context = mock(Context.class);
    Resources resources = mock(Resources.class);
    Configuration config = mock(Configuration.class);
    DartExecutor dartExecutor = mock(DartExecutor.class);
    Locale userLocale = new Locale("es", "MX");
    when(context.getResources()).thenReturn(resources);
    when(resources.getConfiguration()).thenReturn(config);
    setLegacyLocale(config, userLocale);

    flutterJNI.setLocalizationPlugin(
        new LocalizationPlugin(context, new LocalizationChannel(dartExecutor)));

    // Empty supportedLocales.
    String[] supportedLocales = new String[] {};
    String[] result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    assertEquals(result.length, 0);

    // Empty null preferred locale.
    supportedLocales =
        new String[] {
          "fr", "FR", "",
          "zh", "", "",
          "en", "CA", ""
        };
    userLocale = null;
    setLegacyLocale(config, userLocale);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    // The first locale is default.
    assertEquals(result.length, 3);
    assertEquals(result[0], "fr");
    assertEquals(result[1], "FR");
    assertEquals(result[2], "");

    // Example from https://developer.android.com/guide/topics/resources/multilingual-support#postN
    supportedLocales =
        new String[] {
          "en", "", "",
          "de", "DE", "",
          "es", "ES", "",
          "fr", "FR", "",
          "it", "IT", ""
        };
    userLocale = new Locale("fr", "CH");
    setLegacyLocale(config, userLocale);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    assertEquals(result.length, 3);
    assertEquals(result[0], "en");
    assertEquals(result[1], "");
    assertEquals(result[2], "");

    supportedLocales =
        new String[] {
          "en", "", "",
          "de", "DE", "",
          "es", "ES", "",
          "fr", "FR", "",
          "it", "IT", ""
        };
    userLocale = new Locale("it", "IT");
    setLegacyLocale(config, userLocale);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    assertEquals(result.length, 3);
    assertEquals(result[0], "it");
    assertEquals(result[1], "IT");
    assertEquals(result[2], "");

    supportedLocales =
        new String[] {
          "en", "", "",
          "de", "DE", "",
          "es", "ES", "",
          "fr", "FR", "",
          "fr", "", "",
          "it", "IT", ""
        };
    userLocale = new Locale("fr", "CH");
    setLegacyLocale(config, userLocale);
    result = flutterJNI.computePlatformResolvedLocale(supportedLocales);
    assertEquals(result.length, 3);
    assertEquals(result[0], "fr");
    assertEquals(result[1], "");
    assertEquals(result[2], "");
  }

  // Tests the legacy pre API 21 algorithm.
  @Config(sdk = 16)
  @Test
  public void localeFromString_languageOnly() {
    Locale locale = LocalizationPlugin.localeFromString("en");
    assertEquals(locale, new Locale("en"));
  }

  @Config(sdk = 16)
  @Test
  public void localeFromString_languageAndCountry() {
    Locale locale = LocalizationPlugin.localeFromString("en-US");
    assertEquals(locale, new Locale("en", "US"));
  }

  @Config(sdk = 16)
  @Test
  public void localeFromString_languageCountryAndVariant() {
    Locale locale = LocalizationPlugin.localeFromString("zh-Hans-CN");
    assertEquals(locale, new Locale("zh", "CN", "Hans"));
  }

  @Config(sdk = 16)
  @Test
  public void localeFromString_underscore() {
    Locale locale = LocalizationPlugin.localeFromString("zh_Hans_CN");
    assertEquals(locale, new Locale("zh", "CN", "Hans"));
  }

  @Config(sdk = 16)
  @Test
  public void localeFromString_additionalVariantsAreIgnored() {
    Locale locale = LocalizationPlugin.localeFromString("de-DE-u-co-phonebk");
    assertEquals(locale, new Locale("de", "DE"));
  }

  @Test
  public void getStringResource_withoutLocale() throws JSONException {
    Context context = mock(Context.class);
    Resources resources = mock(Resources.class);
    DartExecutor dartExecutor = mock(DartExecutor.class);
    LocalizationChannel localizationChannel = new LocalizationChannel(dartExecutor);
    LocalizationPlugin plugin = new LocalizationPlugin(context, localizationChannel);

    MethodChannel.Result mockResult = mock(MethodChannel.Result.class);

    String fakePackageName = "package_name";
    String fakeKey = "test_key";
    int fakeId = 123;

    when(context.getPackageName()).thenReturn(fakePackageName);
    when(context.getResources()).thenReturn(resources);
    when(resources.getIdentifier(fakeKey, "string", fakePackageName)).thenReturn(fakeId);
    when(resources.getString(fakeId)).thenReturn("test_value");

    JSONObject param = new JSONObject();
    param.put("key", fakeKey);

    localizationChannel.handler.onMethodCall(
        new MethodCall("Localization.getStringResource", param), mockResult);

    verify(mockResult).success("test_value");
  }

  @Test
  public void getStringResource_withLocale() throws JSONException {
    Context context = mock(Context.class);
    Context localContext = mock(Context.class);
    Resources resources = mock(Resources.class);
    Resources localResources = mock(Resources.class);
    Configuration configuration = new Configuration();
    DartExecutor dartExecutor = mock(DartExecutor.class);
    LocalizationChannel localizationChannel = new LocalizationChannel(dartExecutor);
    LocalizationPlugin plugin = new LocalizationPlugin(context, localizationChannel);

    MethodChannel.Result mockResult = mock(MethodChannel.Result.class);

    String fakePackageName = "package_name";
    String fakeKey = "test_key";
    int fakeId = 123;

    when(context.getPackageName()).thenReturn(fakePackageName);
    when(context.createConfigurationContext(any())).thenReturn(localContext);
    when(context.getResources()).thenReturn(resources);
    when(localContext.getResources()).thenReturn(localResources);
    when(resources.getConfiguration()).thenReturn(configuration);
    when(localResources.getIdentifier(fakeKey, "string", fakePackageName)).thenReturn(fakeId);
    when(localResources.getString(fakeId)).thenReturn("test_value");

    JSONObject param = new JSONObject();
    param.put("key", fakeKey);
    param.put("locale", "en-US");

    localizationChannel.handler.onMethodCall(
        new MethodCall("Localization.getStringResource", param), mockResult);

    verify(mockResult).success("test_value");
  }

  @Test
  public void getStringResource_nonExistentKey() throws JSONException {
    Context context = mock(Context.class);
    Resources resources = mock(Resources.class);
    DartExecutor dartExecutor = mock(DartExecutor.class);
    LocalizationChannel localizationChannel = new LocalizationChannel(dartExecutor);
    LocalizationPlugin plugin = new LocalizationPlugin(context, localizationChannel);

    MethodChannel.Result mockResult = mock(MethodChannel.Result.class);

    String fakePackageName = "package_name";
    String fakeKey = "test_key";

    when(context.getPackageName()).thenReturn(fakePackageName);
    when(context.getResources()).thenReturn(resources);
    when(resources.getIdentifier(fakeKey, "string", fakePackageName))
        .thenReturn(0); // 0 means not exist

    JSONObject param = new JSONObject();
    param.put("key", fakeKey);

    localizationChannel.handler.onMethodCall(
        new MethodCall("Localization.getStringResource", param), mockResult);

    verify(mockResult).success(null);
  }

  private static void setApiVersion(int apiVersion) {
    try {
      Field field = Build.VERSION.class.getField("SDK_INT");

      field.setAccessible(true);
      Field modifiersField = Field.class.getDeclaredField("modifiers");
      modifiersField.setAccessible(true);
      modifiersField.setInt(field, field.getModifiers() & ~Modifier.FINAL);

      field.set(null, apiVersion);
    } catch (Exception e) {
      assertTrue(false);
    }
  }

  private static void setLegacyLocale(Configuration config, Locale locale) {
    try {
      Field field = config.getClass().getField("locale");
      field.setAccessible(true);
      Field modifiersField = Field.class.getDeclaredField("modifiers");
      modifiersField.setAccessible(true);
      modifiersField.setInt(field, field.getModifiers() & ~Modifier.FINAL);

      field.set(config, locale);
    } catch (Exception e) {
      assertTrue(false);
    }
  }
}
