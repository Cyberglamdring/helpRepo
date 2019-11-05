package com.test;

import org.junit.Test;
import static org.junit.Assert.*;

public class UnitTest {
    @Test public void testAppHasAGreeting() {
        Project classUnderTest = new Project();
        assertNotNull("app should have a greeting",
                       classUnderTest.getGreeting());
    }

   @Test
   public void test(){
     Project.test();
   }
}
