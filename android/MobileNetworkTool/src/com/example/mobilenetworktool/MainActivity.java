package com.example.mobilenetworktool;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import com.github.koszoaron.mobilenetworktool.R;

public class MainActivity extends Activity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        Intent intentMNSettings = new Intent(Intent.ACTION_MAIN);
        intentMNSettings.setClassName("com.android.phone", "com.android.phone.NetworkSetting");
        startActivity(intentMNSettings);
        
        finish();
    }
}
